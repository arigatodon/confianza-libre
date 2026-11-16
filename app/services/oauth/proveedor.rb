require "net/http"

module Oauth
  # Base de los proveedores de acceso externo (OAuth 2.0 / OpenID Connect,
  # flujo authorization code). Sin gems: son dos requests HTTP.
  #
  #   proveedor = Oauth::Proveedor.para("google")   # nil si no existe
  #   proveedor.configurada?                         # tiene client id + secret
  #   proveedor.authorize_url(state:, redirect_uri:) # a dónde mandar al usuario
  #   proveedor.perfil(code:, redirect_uri:)         # tras el callback → Perfil
  #
  # Cada subclase define NOMBRE, las URLs y de dónde saca las credenciales.
  class Proveedor
    class Error < StandardError; end

    Perfil = Struct.new(:uid, :email, :nombre, :avatar_url, :email_verificado, keyword_init: true)

    TIMEOUT_SEG = 15

    def self.para(nombre)
      case nombre.to_s
      when "google"    then Google.new
      when "microsoft" then Microsoft.new
      end
    end

    def self.configurados
      OauthIdentity::PROVIDERS.filter_map { |n| para(n) }.select(&:configurada?)
    end

    def nombre = self.class::NOMBRE

    def configurada? = client_id.present? && client_secret.present?

    def authorize_url(state:, redirect_uri:)
      query = {
        client_id:     client_id,
        redirect_uri:  redirect_uri,
        response_type: "code",
        scope:         scope,
        state:         state
      }.merge(parametros_extra)
      "#{authorize_endpoint}?#{URI.encode_www_form(query)}"
    end

    # Canjea el código por tokens y arma el perfil con el endpoint userinfo
    # (y los claims del id_token como respaldo). Lanza Oauth::Proveedor::Error.
    def perfil(code:, redirect_uri:)
      tokens = post_form(token_endpoint,
        code:          code,
        client_id:     client_id,
        client_secret: client_secret,
        redirect_uri:  redirect_uri,
        grant_type:    "authorization_code")

      access_token = tokens["access_token"].presence or raise Error, "el proveedor no devolvió access_token"
      claims = claims_del_id_token(tokens["id_token"])
      info   = get_json(userinfo_endpoint, access_token) rescue {}

      construir_perfil(info, claims)
    end

    private

    def parametros_extra = {}
    def scope = "openid email profile"

    def construir_perfil(info, claims)
      uid   = info["sub"].presence || claims["sub"].presence
      email = info["email"].presence || claims["email"].presence || claims["preferred_username"].presence
      raise Error, "el proveedor no entregó un identificador de cuenta" if uid.blank?

      Perfil.new(
        uid:              uid,
        email:            email&.to_s&.strip&.downcase,
        nombre:           info["name"].presence || claims["name"].presence,
        avatar_url:       info["picture"].presence,
        email_verificado: email_verificado?(info, claims)
      )
    end

    # Por defecto, verificado si el proveedor lo afirma explícitamente.
    def email_verificado?(info, claims)
      valor = info.key?("email_verified") ? info["email_verified"] : claims["email_verified"]
      ActiveModel::Type::Boolean.new.cast(valor) == true
    end

    # El id_token llega directo del proveedor por TLS en la respuesta del canje
    # (no del navegador), así que sus claims son confiables sin verificar la
    # firma. Solo se usan como respaldo del userinfo.
    def claims_del_id_token(id_token)
      return {} if id_token.blank?
      payload = id_token.split(".")[1].to_s
      JSON.parse(Base64.urlsafe_decode64(payload + "=" * (-payload.length % 4)))
    rescue ArgumentError, JSON::ParserError
      {}
    end

    def post_form(url, **campos)
      uri = URI(url)
      peticion = Net::HTTP::Post.new(uri)
      peticion["Accept"] = "application/json"
      peticion.set_form_data(campos)
      ejecutar(uri, peticion)
    end

    def get_json(url, access_token)
      uri = URI(url)
      peticion = Net::HTTP::Get.new(uri)
      peticion["Accept"] = "application/json"
      peticion["Authorization"] = "Bearer #{access_token}"
      ejecutar(uri, peticion)
    end

    def ejecutar(uri, peticion)
      respuesta = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                                  open_timeout: TIMEOUT_SEG, read_timeout: TIMEOUT_SEG) do |http|
        http.request(peticion)
      end
      cuerpo = JSON.parse(respuesta.body.to_s.presence || "{}")
      unless respuesta.is_a?(Net::HTTPSuccess)
        detalle = cuerpo["error_description"] || cuerpo["error"] || respuesta.code
        raise Error, "#{nombre}: #{detalle}"
      end
      cuerpo
    rescue JSON::ParserError
      raise Error, "#{nombre}: respuesta ilegible"
    rescue Timeout::Error, SocketError, Errno::ECONNREFUSED, OpenSSL::SSL::SSLError => e
      raise Error, "#{nombre}: no pudimos conectar (#{e.class.name.demodulize})"
    end
  end
end
