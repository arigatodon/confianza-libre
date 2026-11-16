# Aval comunitario: un vecino de nivel alto (curador, nivel 3+) da fe de que
# otra persona es real y de fiar. Al juntar N avales (parámetro gobernable
# endorsements_to_verify) la verificación sube de "email" a "avalado por
# vecinos" — el segundo escalón, sin SMS de por medio: aquí la identidad
# también la respalda la comunidad.
class Endorsement < ApplicationRecord
  belongs_to :endorser, class_name: "User"
  belongs_to :endorsed, class_name: "User"

  validates :endorser_id, uniqueness: { scope: :endorsed_id, message: "ya avalaste a esta persona" }
  validate  :not_self
  validate  :endorser_can_vouch
  validate  :endorsed_has_verified_email

  after_create_commit :notify_endorsed
  after_create_commit :upgrade_verification_if_due

  def self.required_count
    EconomicParameter.get_int("endorsements_to_verify", 3)
  end

  private

  def not_self
    errors.add(:base, "no puedes avalarte a ti mismo") if endorser_id == endorsed_id
  end

  def endorser_can_vouch
    return if endorser.nil? || endorser.moderator?
    errors.add(:base, "solo los moderadores de la comunidad pueden avalar — el aval es responsabilidad de quienes cuidan la red")
  end

  def endorsed_has_verified_email
    return if endorsed.nil? || !endorsed.verification_unverified?
    errors.add(:base, "esa cuenta todavía no verificó su email")
  end

  def notify_endorsed
    NotificationCreator.call(
      recipient:  endorsed,
      actor:      endorser,
      notifiable: self,
      kind:       "endorsement",
      body:       "@#{endorser.username} te avaló como vecino de confianza"
    )
  end

  # email → phone (etiquetado "Avalado por vecinos" en la UI) al juntar los
  # avales requeridos. No pisa identity ni baja a nadie.
  def upgrade_verification_if_due
    return unless endorsed.verification_email?
    return if Endorsement.where(endorsed_id: endorsed_id).count < self.class.required_count

    endorsed.update!(verification_level: :phone)
    NotificationCreator.call(
      recipient:  endorsed,
      notifiable: self,
      kind:       "endorsement",
      body:       "¡Tus vecinos te avalaron! Tu verificación subió: ya cuentas como avalado por la comunidad."
    )
  end
end
