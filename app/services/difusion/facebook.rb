require "net/http"

module Difusion
  # Publica un post en la página de Facebook de Confianza vía Graph API.
  #
  # A diferencia de Instagram no sube la imagen: publica texto + link al post
  # (POST /{page-id}/feed). Facebook arma la vista previa con la og:image del
  # post — que es justamente la tarjeta — y el resultado queda clickeable,
  # lo que convierte mejor que una foto suelta.
  #
  # Usa la misma app de Meta que Instagram (permiso pages_manage_posts).
  #
  # Variables de entorno:
  #   FACEBOOK_PAGE_ID           — id numérico de la página
  #   FACEBOOK_PAGE_ACCESS_TOKEN — Page Access Token de larga duración
  class Facebook
    NETWORK = "facebook"
    HOST    = "https://graph.facebook.com"
    VERSION = "v21.0"

    def self.configurada? = ENV["FACEBOOK_PAGE_ID"].present? && ENV["FACEBOOK_PAGE_ACCESS_TOKEN"].present?

    # Devuelve el id del post publicado en la página. Lanza si Meta responde error.
    # tarjeta_png: y tarjeta_url: se ignoran (la vista previa sale de la og:image).
    def publicar(tarjeta_png:, texto:, url:, tarjeta_url: nil)
      respuesta = post_form("#{pagina}/feed", message: texto, link: url)
      respuesta.fetch("id")
    end

    private

    def pagina = ENV["FACEBOOK_PAGE_ID"]

    def post_form(ruta, **campos)
      uri = URI("#{HOST}/#{VERSION}/#{ruta}")
      peticion = Net::HTTP::Post.new(uri)
      peticion.set_form_data(campos.merge(access_token: ENV["FACEBOOK_PAGE_ACCESS_TOKEN"]))

      respuesta = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 30) do |http|
        http.request(peticion)
      end

      cuerpo = JSON.parse(respuesta.body)
      unless respuesta.is_a?(Net::HTTPSuccess)
        error = cuerpo.dig("error", "message") || respuesta.code
        raise "Facebook: #{error}"
      end
      cuerpo
    end
  end
end
