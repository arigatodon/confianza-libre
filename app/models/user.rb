class User < ApplicationRecord
  extend FriendlyId
  include PgSearch::Model
  friendly_id :username, use: :slugged

  reverse_geocoded_by :latitude, :longitude

  # Búsqueda de vecinos: usuario y titular (peso A) + bio (peso B), sobre la
  # columna generada `searchable` con la config `spanish_unaccent`.
  pg_search_scope :full_text,
    against: { username: "A", headline: "A", bio: "B" },
    using: {
      tsearch: { tsvector_column: "searchable", dictionary: "spanish_unaccent", prefix: true }
    }

  STATUSES = { active: 0, pending: 1, suspended: 2 }.freeze
  VERIFICATION_LEVELS = { unverified: 0, email: 1, phone: 2, identity: 3 }.freeze

  enum :status, STATUSES
  enum :verification_level, VERIFICATION_LEVELS, prefix: :verification

  has_secure_password
  has_many :sessions, dependent: :destroy

  # Token firmado para verificar email (sin columna en DB). Vence en 7 días.
  # Si el email_address cambia, el token previo se invalida automáticamente.
  generates_token_for :email_verification, expires_in: 7.days do
    email_address
  end

  belongs_to :sponsor, class_name: "User", optional: true
  has_many :sponsored_users, class_name: "User", foreign_key: :sponsor_id, dependent: :nullify

  has_many :posts, dependent: :destroy
  has_many :accounts, dependent: :destroy
  has_one  :credit_account, -> { where(account_type: "user") }, class_name: "Account", inverse_of: :user
  has_many :proposals, foreign_key: :proposer_id, dependent: :destroy, inverse_of: :proposer
  has_many :proposal_votes, dependent: :destroy
  has_many :comments, dependent: :destroy

  has_one_attached :avatar

  has_many :reviews_given,    class_name: "Review", foreign_key: :reviewer_id,      dependent: :destroy, inverse_of: :reviewer
  has_many :reviews_received, class_name: "Review", foreign_key: :reviewed_user_id, dependent: :destroy, inverse_of: :reviewed_user

  has_many :interactions_sent,     class_name: "Interaction", foreign_key: :sender_id,   dependent: :destroy, inverse_of: :sender
  has_many :interactions_received, class_name: "Interaction", foreign_key: :receiver_id, dependent: :destroy, inverse_of: :receiver

  has_many :notifications,        class_name: "Notification", foreign_key: :recipient_id, dependent: :destroy, inverse_of: :recipient
  has_many :triggered_notifications, class_name: "Notification", foreign_key: :actor_id, dependent: :nullify, inverse_of: :actor

  has_many :push_subscriptions, dependent: :destroy
  has_many :identity_verifications, dependent: :destroy
  has_many :saved_searches, dependent: :destroy
  has_many :endorsements_received, class_name: "Endorsement", foreign_key: :endorsed_id, dependent: :destroy, inverse_of: :endorsed
  has_many :endorsements_given,    class_name: "Endorsement", foreign_key: :endorser_id, dependent: :destroy, inverse_of: :endorser

  has_many :reports,            as: :reportable, dependent: :destroy
  has_many :reports_filed,      class_name: "Report", foreign_key: :reporter_id,    dependent: :destroy
  has_many :reports_moderated,  class_name: "Report", foreign_key: :resolved_by_id, dependent: :nullify

  # API pública (publicar desde un sitio propio) y acceso con Google/Microsoft.
  has_many :api_keys,         dependent: :destroy
  has_many :oauth_identities, dependent: :destroy

  validates :headline, length: { maximum: 80 }

  # ── Vitrina 2.0 ────────────────────────────────────────────────────────────
  # Plantillas por rubro: cambian el orden de secciones del perfil público,
  # el nombre de la sección de publicaciones y el texto del botón de WhatsApp.
  VITRINA_PLANTILLAS = {
    "tienda"      => { nombre: "Tienda / almacén",   icono: "storefront", seccion_posts: "Catálogo",      cta: "Pedir por WhatsApp", posts_primero: true },
    "oficio"      => { nombre: "Oficio / servicios", icono: "handyman",   seccion_posts: "Servicios",     cta: "Pedir presupuesto",  posts_primero: false },
    "comida"      => { nombre: "Comida / delivery",  icono: "restaurant", seccion_posts: "Menú",          cta: "Pedir ahora",        posts_primero: true },
    "eventos"     => { nombre: "Eventos",            icono: "event",      seccion_posts: "Agenda",        cta: "Consultar",          posts_primero: true },
    "profesional" => { nombre: "Profesional",        icono: "badge",      seccion_posts: "Publicaciones", cta: "Contactar",          posts_primero: false },
    "comunidad"   => { nombre: "Comunidad / organización", icono: "groups", seccion_posts: "Actividades", cta: "Contactar",          posts_primero: true }
  }.freeze

  PLANTILLA_DEFAULT = { nombre: "Clásica", icono: "person", seccion_posts: "Publicaciones", cta: "Contactar", posts_primero: false }.freeze

  # Acentos permitidos (paleta Capital Comunitario): todos con contraste
  # suficiente para texto blanco encima.
  ACCENT_COLORS = {
    "#0f5238" => "Verde",
    "#924c00" => "Tierra",
    "#004d6c" => "Azul",
    "#333333" => "Grafito"
  }.freeze

  has_one_attached :portada
  store_accessor :vitrina_links, :instagram, :facebook, :web, prefix: :link

  normalizes :whatsapp, with: ->(w) { w.gsub(/[\s\-().]/, "") }

  # Handle real de Instagram del usuario, sacado del enlace de su vitrina.
  # Hace falta para etiquetarlo cuando difundimos su publicación: el @usuario de
  # Confianza no tiene por qué existir en Instagram y, si existe, es otra persona
  # —etiquetar a un desconocido es peor que no etiquetar a nadie—.
  # Acepta la URL completa o el handle escrito a mano; devuelve nil si no sirve.
  def instagram_handle
    valor = link_instagram.to_s.strip
    return nil if valor.blank?

    handle = valor[%r{instagram\.com/+([^/?#\s]+)}i, 1] || valor
    handle = handle.delete_prefix("@").strip
    handle.downcase if handle.match?(/\A[a-z0-9._]{1,30}\z/i)
  end

  validates :whatsapp, format: { with: /\A\+?\d{8,15}\z/, message: "debe ser un número con código de país, ej: +56912345678" }, allow_blank: true
  validates :horario, length: { maximum: 120 }
  validates :vitrina_plantilla, inclusion: { in: VITRINA_PLANTILLAS.keys, message: "no es una plantilla válida" }, allow_blank: true
  validates :accent_color, inclusion: { in: ACCENT_COLORS.keys, message: "no es un color permitido" }, allow_blank: true
  validate :vitrina_links_deben_ser_http

  # Vitrinas: perfiles que eligieron ser públicos (escaparate de servicios).
  scope :showcases, -> { where(showcase: true) }

  def plantilla
    VITRINA_PLANTILLAS[vitrina_plantilla] || PLANTILLA_DEFAULT
  end

  def acento
    accent_color.presence || "#0f5238"
  end

  # Link de contacto directo. El texto lleva al negocio el contexto de dónde
  # viene el cliente — es la conversión que la vitrina promete.
  def whatsapp_url
    return nil if whatsapp.blank?
    texto = "Hola @#{username}, vi tu vitrina en Confianza y quiero contactarte."
    "https://wa.me/#{whatsapp.delete_prefix('+')}?text=#{ERB::Util.url_encode(texto)}"
  end

  # El perfil COMPLETO (bio, stats, padrino, avales) lo ve cualquier usuario
  # con sesión, o cualquiera si el dueño activó su vitrina. Sin sesión y sin
  # vitrina se muestra solo la tarjeta mínima.
  def full_profile_visible_to?(viewer)
    showcase? || viewer.present?
  end

  # El rol de moderación es un flag otorgable/revocable por gobernanza
  # (Fase 1.3), ya NO se deriva del nivel económico: acumular crédito no da
  # poder de policía. Bootstrap: los L3+ y admins lo recibieron en la migración.
  def moderator?
    moderator_since.present?
  end

  def grant_moderation!
    update!(moderator_since: Time.current) unless moderator?
  end

  def revoke_moderation!
    update!(moderator_since: nil) if moderator?
  end

  # Preferencias de match (Fase 2.2). Las categorías de interés: las elegidas
  # explícitamente, o si no eligió ninguna, las de sus propias publicaciones.
  scope :match_enabled, -> { where(match_notifications: true) }

  def matchable_category_ids
    return match_category_ids if match_category_ids.present?
    posts.visible.distinct.pluck(:category_id)
  end

  def wants_match_for?(category_id)
    match_notifications? && matchable_category_ids.include?(category_id)
  end

  def onboarded?
    onboarding_completed_at.present?
  end

  def complete_onboarding!
    return if onboarded?
    update!(onboarding_completed_at: Time.current)
  end

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # Nombres que chocarían con rutas propias (el perfil vive en /:username).
  RESERVED_USERNAMES = %w[
    api auth admin ajustes settings session signup invita bienvenida posts explore
    vecinos billetera logros novedades mensajes territorios moderacion feedback
    economia manifiesto privacidad up sitemap ledger notifications proposals
    reports interactions reviews alertas identidad configurations metricas explorar
  ].freeze

  validates :username, presence: true, uniqueness: { case_sensitive: false },
            length: { in: 3..30 },
            format: { with: /\A[a-z0-9_]+\z/i, message: "solo letras, números y guion bajo" }
  validates :username, exclusion: { in: RESERVED_USERNAMES, message: "no está disponible" },
            if: :will_save_change_to_username?
  validates :email_address, presence: true, uniqueness: true,
            format: { with: URI::MailTo::EMAIL_REGEXP, message: "no parece un email válido" }
  validates :password, length: { minimum: 8 }, if: -> { password.present? }

  after_create_commit :ensure_credit_account!
  # Quien entra con Google/Microsoft ya trae el email verificado por el
  # proveedor: no tiene sentido pedirle que lo confirme de nuevo.
  after_create_commit :send_email_verification, unless: :email_verified?

  def email_verified?
    email_verified_at.present?
  end

  def mark_email_verified!
    return if email_verified?
    self.email_verified_at = Time.current
    # Subir verification_level mínimo a :email (no bajar si ya es phone/identity).
    self.verification_level = :email if verification_unverified?
    save!
    RecalculateUserLevelJob.perform_later(id)
    WelcomeMailer.welcome(self).deliver_later
  end

  def send_email_verification
    EmailVerificationMailer.confirm(self).deliver_later
  end

  def to_s
    username.presence || email_address
  end

  # Proveedores externos con los que puede entrar (Google, Microsoft…).
  def oauth_providers
    oauth_identities.pluck(:provider)
  end

  # Asegura que el usuario tenga su `Account` `user` con saldo 0.
  # Idempotente — el partial unique index garantiza una sola cuenta `user` por user.
  # Carga la asociación en memoria para que `user.credit_account` funcione sin reload.
  def ensure_credit_account!
    existing = credit_account || accounts.find_by(account_type: "user")
    return existing if existing
    account = accounts.create!(account_type: "user", cached_balance: 0)
    association(:credit_account).target = account
    account
  end

  # Saldo disponible (cached + colchón negativo permitido por el nivel).
  def available_balance
    (credit_account&.cached_balance || 0) + credit_floor.to_i
  end

  private

  # Solo http/https en los links de la vitrina: un href con javascript: u otro
  # esquema inyectado en el perfil público sería XSS servido por nosotros.
  def vitrina_links_deben_ser_http
    (vitrina_links || {}).each do |clave, valor|
      next if valor.blank?
      uri = URI.parse(valor)
      unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
        errors.add(:vitrina_links, "el link de #{clave} debe empezar con https://")
      end
    rescue URI::InvalidURIError
      errors.add(:vitrina_links, "el link de #{clave} no es una URL válida")
    end
  end
end
