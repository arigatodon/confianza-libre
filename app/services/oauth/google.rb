module Oauth
  # Acceso con cuenta de Google (Gmail). Credenciales: proyecto en Google Cloud
  # → APIs y servicios → Credenciales → ID de cliente OAuth (aplicación web),
  # con https://confianza.world/auth/google/callback como URI autorizada.
  #
  # Variables de entorno:
  #   GOOGLE_OAUTH_CLIENT_ID
  #   GOOGLE_OAUTH_CLIENT_SECRET
  class Google < Proveedor
    NOMBRE = "google"

    def client_id     = ENV["GOOGLE_OAUTH_CLIENT_ID"]
    def client_secret = ENV["GOOGLE_OAUTH_CLIENT_SECRET"]

    private

    def authorize_endpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    def token_endpoint     = "https://oauth2.googleapis.com/token"
    def userinfo_endpoint  = "https://openidconnect.googleapis.com/v1/userinfo"

    # select_account: que pueda elegir cuál Gmail usar aunque tenga una sesión.
    def parametros_extra = { prompt: "select_account" }
  end
end
