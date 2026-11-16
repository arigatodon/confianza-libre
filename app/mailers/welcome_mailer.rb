class WelcomeMailer < ApplicationMailer
  # Se dispara una sola vez, cuando el usuario verifica su email
  # (User#mark_email_verified!).
  def welcome(user)
    @user = user
    mail subject: "¡Tu cuenta en Confianza ya está activa! 🤝", to: user.email_address
  end
end
