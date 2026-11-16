# Aprueba o rechaza una solicitud de verificación de identidad.
#
# Reglas de autorización:
#   - El revisor debe ser moderador L3+.
#   - La solicitud debe estar pendiente.
#
# Aprobar: sube al usuario a verification_level :identity (sin bajarlo si ya
# estuviera más alto) y dispara RecalculateUserLevelJob para recalcular su cupo.
# Rechazar: exige un motivo; el usuario puede volver a intentar.
class IdentityReviewer
  Result = Struct.new(:verification, :error, keyword_init: true) do
    def ok? = verification.present? && error.nil?
  end

  def self.call(...) = new(...).call

  def initialize(verification:, moderator:, decision:, note: nil)
    @verification = verification
    @moderator    = moderator
    @decision     = decision.to_s
    @note         = note.to_s.strip.presence
  end

  def call
    return fail(:unauthorized)     unless @moderator&.moderator?
    return fail(:already_resolved) unless @verification.pending?
    return fail(:invalid_decision) unless %w[approve reject].include?(@decision)
    return fail(:note_required)    if @decision == "reject" && @note.nil?

    @decision == "approve" ? approve! : reject!
    Result.new(verification: @verification.reload)
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn("[IdentityReviewer] #{e.message}")
    fail(:invalid)
  end

  private

  def approve!
    ActiveRecord::Base.transaction do
      @verification.update!(status: :approved, reviewed_by: @moderator,
                            reviewed_at: Time.current, note: @note)
      user = @verification.user
      # No degradar si ya tuviera un nivel de verificación mayor.
      unless user.verification_identity?
        user.update_columns(verification_level: User::VERIFICATION_LEVELS[:identity])
      end
    end
    RecalculateUserLevelJob.perform_later(@verification.user_id)
    notify(:approved, "Tu identidad fue verificada. ¡Gracias por sumar confianza a la red!")
  end

  def reject!
    @verification.update!(status: :rejected, reviewed_by: @moderator,
                          reviewed_at: Time.current, note: @note)
    notify(:rejected, "Tu verificación de identidad fue rechazada: #{@note} Puedes volver a intentarlo.")
  end

  def notify(_kind, body)
    NotificationCreator.call(
      recipient:  @verification.user,
      actor:      @moderator,
      notifiable: @verification,
      kind:       "identity_review",
      body:       body
    )
  end

  def fail(error)
    Result.new(verification: nil, error: error)
  end
end
