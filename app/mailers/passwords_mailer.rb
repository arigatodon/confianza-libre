class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    mail subject: "Restablece tu contraseña en Confianza", to: user.email_address
  end
end
