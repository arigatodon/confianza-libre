class EmailVerificationMailer < ApplicationMailer
  def confirm(user)
    @user  = user
    @token = user.generate_token_for(:email_verification)
    mail subject: "Confirma tu cuenta en Confianza", to: user.email_address
  end
end
