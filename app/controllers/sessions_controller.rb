class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Demasiados intentos — prueba de nuevo en unos minutos." }

  def new
  end

  def create
    if (user = authenticate)
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "Email o contraseña incorrectos."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end

  private

  # Envuelve authenticate_by para que un password_digest corrupto (no-bcrypt)
  # falle como credencial inválida en lugar de tirar un 500.
  def authenticate
    User.authenticate_by(params.permit(:email_address, :password))
  rescue BCrypt::Errors::InvalidHash
    nil
  end
end
