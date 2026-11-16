# Novedades oficiales del proyecto: cambios, versiones y consultas a la
# comunidad. Públicas e indexables — el desarrollo se cuenta abierto, en el
# mismo dominio donde pasa.
class Announcement < ApplicationRecord
  extend FriendlyId
  friendly_id :title, use: :slugged

  # cambio   — qué se construyó y por qué, en lenguaje simple.
  # version  — hitos agrupados (v0.x), resumen de un ciclo.
  # consulta — dirección de desarrollo abierta a la señal de la comunidad:
  #            los apoyos pesan antes de construir.
  KINDS = { cambio: 0, version: 1, consulta: 2 }.freeze
  enum :kind, KINDS

  KIND_LABELS_ES = {
    "cambio"   => "Cambio",
    "version"  => "Versión",
    "consulta" => "En consulta"
  }.freeze

  belongs_to :user
  has_many :supports, class_name: "AnnouncementSupport", dependent: :destroy

  validates :title, presence: true, length: { in: 5..120 }
  validates :body,  presence: true, length: { minimum: 20 }

  scope :published, -> { where(published_at: ..Time.current) }
  scope :recent,    -> { order(Arel.sql("published_at DESC NULLS FIRST"), created_at: :desc) }

  def published? = published_at.present? && published_at <= Time.current

  def kind_label_es
    KIND_LABELS_ES[kind] || kind.to_s.humanize
  end

  def supported_by?(user)
    return false unless user
    supports.exists?(user_id: user.id)
  end

  # Resumen para meta description y listados.
  def excerpt(limit = 200)
    body.to_s.gsub(/\s+/, " ").strip.truncate(limit, separator: " ")
  end

  # Generar slug siempre que falte; regenerarlo sólo si el título cambia antes
  # de publicar (una URL publicada no se rompe).
  def should_generate_new_friendly_id?
    slug.blank? || (title_changed? && !published?)
  end
end
