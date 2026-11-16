class Post < ApplicationRecord
  extend FriendlyId
  include PgSearch::Model
  friendly_id :title, use: :slugged

  # Búsqueda full-text sobre la columna generada `searchable` (título peso A,
  # descripción peso B), con la config `spanish_unaccent` (stemming español +
  # unaccent) para la query. `prefix` hace que "gasfiter" alcance "gasfitería".
  pg_search_scope :full_text,
    against: { title: "A", description: "B" },
    using: {
      tsearch: { tsvector_column: "searchable", dictionary: "spanish_unaccent", prefix: true }
    }

  # Geocoder usa por defecto las columnas latitude/longitude de la tabla, lo
  # que habilita Post.near([lat, lng], radius). El navegador captura lat/lng
  # directamente, así que no hace falta geocodificar por dirección textual.
  reverse_geocoded_by :latitude, :longitude

  KINDS = %w[venta servicio delivery evento ayuda propuesta noticia blog].freeze
  STATUSES = { draft: 0, published: 1, paused: 2, closed: 3, archived: 4 }.freeze

  # Mapping de categoría → kind. Permite que el usuario sólo elija categoría
  # en el form (kind se infiere). El default es "servicio" si la categoría
  # no está mapeada.
  CATEGORY_TO_KIND = {
    "servicios"   => "servicio",
    "productos"   => "venta",
    "delivery"    => "delivery",
    "eventos"     => "evento",
    "ayuda"       => "ayuda",
    "comunidad"   => "propuesta",
    "información" => "noticia",
    "informacion" => "noticia"
  }.freeze

  STATUS_LABELS_ES = {
    "draft"     => "Borrador",
    "published" => "Publicado",
    "paused"    => "Pausado",
    "closed"    => "Cerrado",
    "archived"  => "Archivado"
  }.freeze

  KIND_LABELS_ES = {
    "venta"     => "Venta",
    "servicio"  => "Servicio",
    "delivery"  => "Delivery",
    "evento"    => "Evento",
    "ayuda"     => "Ayuda",
    "propuesta" => "Propuesta",
    "noticia"   => "Noticia",
    "blog"      => "Blog"
  }.freeze

  enum :status, STATUSES

  belongs_to :user
  belongs_to :category

  has_many :interactions, dependent: :destroy
  has_many :reviews,      dependent: :destroy
  has_many :comments,     dependent: :destroy
  has_many :reports, as: :reportable, dependent: :destroy
  has_many :social_broadcasts, dependent: :destroy
  has_many_attached :media

  # Fondo generado con IA para la tarjeta de difusión de posts informativos
  # sin foto (ver Difusion::ImagenIa). Se genera una sola vez en
  # DifundirPostJob y queda adjunto para que todos los renders de la tarjeta
  # (job, og:image, descarga de Meta) usen la misma imagen.
  has_one_attached :imagen_difusion

  def hidden_by_moderation?
    hidden_at.present?
  end

  def coordinates_present?
    latitude.present? && longitude.present?
  end

  # "Ofrezco" vs "busco", para copy y filtros.
  def market_label_es
    pedido? ? "Busca" : "Ofrece"
  end

  validates :title, presence: true, length: { maximum: 140 }
  validates :kind,  presence: true, inclusion: { in: KINDS }
  validates :visibility_radius, numericality: { greater_than: 0 }

  before_validation :infer_kind_from_category, if: -> { kind.blank? && category.present? }

  # Difusión a redes sociales sólo con consentimiento (difundir) y post
  # público. El job es idempotente, así que reencolar no duplica envíos.
  after_commit :programar_difusion, on: [ :create, :update ],
               if: -> { difundir? && published? && !hidden_by_moderation? }

  # Matching automático (Fase 2.2): al publicarse un post, avisar a la otra
  # mitad del mercado cerca (un pedido → quienes ofrecen esa categoría, y
  # viceversa). El job es idempotente (no repite aviso por usuario y post).
  after_commit :programar_matching, on: [ :create, :update ],
               if: -> { published? && !hidden_by_moderation? && coordinates_present? }

  scope :visible, -> { where(status: :published).where(hidden_at: nil) }

  # Las dos mitades del mercado: ofrezco (pedido:false) vs busco (pedido:true).
  scope :offers,  -> { where(pedido: false) }
  scope :pedidos, -> { where(pedido: true) }

  # Filtro de /explore y feed: "ofertas" | "pedidos" | nil (todo).
  scope :of_market, ->(m) {
    case m.to_s
    when "ofertas" then offers
    when "pedidos" then pedidos
    else all
    end
  }

  # Filtros usados por ExploreController. Cada uno es no-op cuando el valor
  # es blank, así que se pueden chainear sin nil-checks en el caller.
  scope :search, ->(q) { q.blank? ? all : full_text(q) }
  scope :in_category,      ->(cid) { cid.present? ? where(category_id: cid) : all }
  scope :of_kind,          ->(k)   { k.present? && KINDS.include?(k.to_s) ? where(kind: k) : all }
  scope :with_max_credits, ->(c)   {
    next all if c.blank?
    where("suggested_credits IS NULL OR suggested_credits <= ?", c.to_i)
  }

  def to_s
    title
  end

  def status_label_es
    STATUS_LABELS_ES[status] || status.to_s.humanize
  end

  def kind_label_es
    KIND_LABELS_ES[kind] || kind.to_s.humanize
  end

  private

  def infer_kind_from_category
    self.kind = CATEGORY_TO_KIND[category.name.to_s.downcase] || "servicio"
  end

  def programar_difusion
    # En updates, sólo cuando cambió algo relevante para la difusión.
    return if persisted? && !previously_new_record? &&
              !(saved_change_to_difundir? || saved_change_to_status?)

    DifundirPostJob.perform_later(id)
  end

  def programar_matching
    # Sólo al recién publicarse: al crear ya publicado, o al pasar a publicado.
    recien_publicado = previously_new_record? ||
                       (saved_change_to_status? && published?)
    return unless recien_publicado

    MatchNotificationJob.perform_later(id)
    SavedSearchAlertJob.perform_later(id)
  end
end
