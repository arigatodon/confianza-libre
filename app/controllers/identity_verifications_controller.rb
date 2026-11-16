class IdentityVerificationsController < ApplicationController
  # El usuario sube 1–2 imágenes de su documento desde /settings. La revisión
  # la hace un moderador en /moderacion.
  def create
    user = Current.session.user
    verification = user.identity_verifications.new(documents: Array(params.dig(:identity_verification, :documents)).compact_blank)

    if verification.save
      redirect_to settings_path, notice: "Recibimos tu documento. Un moderador lo revisará pronto."
    else
      redirect_to settings_path, alert: verification.errors.full_messages.to_sentence
    end
  end
end
