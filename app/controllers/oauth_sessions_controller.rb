# Entrar o crear cuenta con Google / Microsoft.
#
#   GET /auth/:provider           → manda al proveedor (con `state` anti-CSRF en la sesión)
#   GET /auth/:provider/callback  → canjea el código, resuelve el usuario y abre sesión
#
# Quien llega nuevo pasa por /bienvenida como cualquier registro (require_onboarding).
class OauthSessionsController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :require_onboarding

  rate_limit to: 20, within: 3.minutes,
             with: -> { redirect_to new_session_path, alert: "Demasiados intentos — prueba de nuevo en unos minutos." }

  before_action :set_proveedor

  def new
    state = SecureRandom.hex(24)
    session[:oauth_state] = state
    redirect_to @proveedor.authorize_url(state: state, redirect_uri: callback_url), allow_other_host: true
  end

  def create
    state_esperado = session.delete(:oauth_state)

    if params[:error].present?
      return redirect_to new_session_path, alert: "No se completó el acceso con #{etiqueta}."
    end
    unless state_esperado.present? && params[:state].present? &&
           ActiveSupport::SecurityUtils.secure_compare(state_esperado, params[:state].to_s)
      return redirect_to new_session_path, alert: "El acceso con #{etiqueta} venció o no es válido. Intenta de nuevo."
    end

    perfil    = @proveedor.perfil(code: params[:code].to_s, redirect_uri: callback_url)
    resultado = Oauth::Ingreso.call(proveedor: @proveedor.nombre, perfil: perfil,
                                    sponsor_code: session.delete(:sponsor_code))

    if resultado.ok?
      start_new_session_for resultado.user
      if resultado.nuevo?
        redirect_to root_path, notice: "Bienvenido a Confianza, @#{resultado.user.username}. Puedes cambiar tu nombre de usuario en Ajustes."
      else
        redirect_to after_authentication_url
      end
    else
      redirect_to new_session_path, alert: resultado.error
    end
  rescue Oauth::Proveedor::Error => e
    Rails.logger.warn("[OauthSessions] #{e.message}")
    redirect_to new_session_path, alert: "No pudimos completar el acceso con #{etiqueta}. Intenta de nuevo."
  end

  private

  def set_proveedor
    @proveedor = Oauth::Proveedor.para(params[:provider])
    head :not_found unless @proveedor&.configurada?
  end

  def etiqueta = OauthIdentity::PROVIDER_LABELS_ES[@proveedor.nombre]

  def callback_url = oauth_callback_url(@proveedor.nombre)
end
