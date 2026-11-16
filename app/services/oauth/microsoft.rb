module Oauth
  # Acceso con cuenta Microsoft: Hotmail, Outlook, Live y cuentas de trabajo.
  # Credenciales: portal de Azure → Microsoft Entra ID → Registros de
  # aplicaciones → nueva app "Cuentas en cualquier directorio + cuentas
  # personales", URI de redirección (web) https://confianza.world/auth/microsoft/callback,
  # y un secreto de cliente.
  #
  # Variables de entorno:
  #   MICROSOFT_OAUTH_CLIENT_ID
  #   MICROSOFT_OAUTH_CLIENT_SECRET
  class Microsoft < Proveedor
    NOMBRE = "microsoft"

    def client_id     = ENV["MICROSOFT_OAUTH_CLIENT_ID"]
    def client_secret = ENV["MICROSOFT_OAUTH_CLIENT_SECRET"]

    private

    # "common": acepta cuentas personales (Hotmail/Outlook) y de organizaciones.
    def authorize_endpoint = "https://login.microsoftonline.com/common/oauth2/v2.0/authorize"
    def token_endpoint     = "https://login.microsoftonline.com/common/oauth2/v2.0/token"
    def userinfo_endpoint  = "https://graph.microsoft.com/oidc/userinfo"

    def parametros_extra = { response_mode: "query", prompt: "select_account" }

    # Microsoft no manda email_verified: las cuentas personales exigen
    # confirmar el correo al crearse y las de organización las administra el
    # dominio. Se toma como verificado si vino un email.
    def email_verificado?(info, claims)
      (info["email"].presence || claims["email"].presence || claims["preferred_username"].presence).present?
    end
  end
end
