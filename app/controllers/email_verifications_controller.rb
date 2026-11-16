class EmailVerificationsController < ApplicationController
  allow_unauthenticated_access only: :show

  rate_limit to: 5, within: 5.minutes, only: :create,
             with: -> { redirect_to root_path, alert: "Demasiados intentos — prueba de nuevo en unos minutos." }

  # GET /verificar-email/:token — confirma el email.
  def show
    user = User.find_by_token_for(:email_verification, params[:token])

    if user.nil?
      redirect_to root_path, alert: "Enlace inválido o vencido. Pide uno nuevo desde tus ajustes."
      return
    end

    if user.email_verified?
      redirect_to root_path, notice: "Tu email ya estaba verificado."
      return
    end

    user.mark_email_verified!
    redirect_to root_path, notice: "¡Email verificado! Ya puedes iniciar interacciones."
  end

  # POST /verificar-email — reenviar mail al user autenticado.
  def create
    user = Current.session.user
    if user.email_verified?
      redirect_to root_path, notice: "Tu email ya está verificado."
    else
      user.send_email_verification
      redirect_to root_path, notice: "Te enviamos un nuevo enlace de verificación."
    end
  end
end
