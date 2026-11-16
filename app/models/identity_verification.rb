# Solicitud de verificación de identidad: el usuario sube 1–2 imágenes de su
# documento y un moderador L3+ la aprueba (sube a verification_level :identity)
# o la rechaza con un motivo. Las imágenes se purgan a los 30 días de resolver
# (PurgeIdentityDocumentsJob) — no somos custodios de documentos.
class IdentityVerification < ApplicationRecord
  STATUSES   = { pending: 0, approved: 1, rejected: 2 }.freeze
  MAX_IMAGES = 2
  PURGE_AFTER = 30.days

  enum :status, STATUSES

  belongs_to :user
  belongs_to :reviewed_by, class_name: "User", optional: true

  has_many_attached :documents

  validate :documents_present, on: :create
  validate :within_image_limit
  validate :user_email_verified, on: :create
  validate :no_pending_request, on: :create

  scope :recent,   -> { order(created_at: :desc) }
  scope :resolved, -> { where.not(status: :pending) }

  # Solicitudes resueltas hace más de PURGE_AFTER que aún tienen adjuntos.
  scope :purgeable, -> {
    resolved.where(reviewed_at: ..PURGE_AFTER.ago)
            .joins(:documents_attachments)
            .distinct
  }

  def resolved? = !pending?

  private

  def documents_present
    errors.add(:documents, "sube al menos una imagen del documento") unless documents.attached?
  end

  def within_image_limit
    return if documents.blank?
    if documents.size > MAX_IMAGES
      errors.add(:documents, "máximo #{MAX_IMAGES} imágenes")
    end
    unless documents.all? { |d| d.image? }
      errors.add(:documents, "deben ser imágenes")
    end
  end

  def user_email_verified
    return if user&.email_verified?
    errors.add(:base, "Necesitas verificar tu correo antes de validar tu identidad.")
  end

  def no_pending_request
    return unless user
    if user.identity_verifications.pending.exists?
      errors.add(:base, "Ya tienes una solicitud en revisión.")
    end
  end
end
