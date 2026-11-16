require "net/http"

module Difusion
  # Publica la tarjeta de un post en Bluesky (AT Protocol).
  #
  # Variables de entorno:
  #   BLUESKY_IDENTIFIER   — handle (ej: "confianza.world" o "usuario.bsky.social")
  #   BLUESKY_APP_PASSWORD — app password (Settings → App Passwords)
  class Bluesky
    NETWORK = "bluesky"
    HOST    = "https://bsky.social"

    def self.configurada? = ENV["BLUESKY_IDENTIFIER"].present? && ENV["BLUESKY_APP_PASSWORD"].present?

    # Devuelve el at:// uri del post creado. Lanza si la API responde error.
    # tarjeta_url: se ignora (Bluesky sube los bytes como blob).
    def publicar(tarjeta_png:, texto:, url:, tarjeta_url: nil)
      sesion = crear_sesion
      blob   = subir_imagen(sesion, tarjeta_png)

      cuerpo_texto = "#{texto}\n\n#{url}"
      registro = {
        repo:       sesion["did"],
        collection: "app.bsky.feed.post",
        record: {
          "$type"     => "app.bsky.feed.post",
          text:       cuerpo_texto,
          createdAt:  Time.current.iso8601,
          facets:     [ facet_link(cuerpo_texto, url) ].compact,
          embed: {
            "$type" => "app.bsky.embed.images",
            images: [ { alt: texto.truncate(300), image: blob } ]
          }
        }
      }

      respuesta = post_json("/xrpc/com.atproto.repo.createRecord", registro,
                            token: sesion["accessJwt"])
      respuesta.fetch("uri")
    end

    private

    def crear_sesion
      post_json("/xrpc/com.atproto.server.createSession",
                { identifier: ENV["BLUESKY_IDENTIFIER"], password: ENV["BLUESKY_APP_PASSWORD"] })
    end

    def subir_imagen(sesion, png)
      uri = URI("#{HOST}/xrpc/com.atproto.repo.uploadBlob")
      peticion = Net::HTTP::Post.new(uri)
      peticion["Authorization"] = "Bearer #{sesion['accessJwt']}"
      peticion["Content-Type"]  = "image/png"
      peticion.body = png

      respuesta = ejecutar(uri, peticion)
      respuesta.fetch("blob")
    end

    # Vuelve clickeable la URL dentro del texto (Bluesky no linkifica solo).
    def facet_link(texto, url)
      inicio = texto.byteindex(url)
      return nil unless inicio

      {
        index:    { byteStart: inicio, byteEnd: inicio + url.bytesize },
        features: [ { "$type" => "app.bsky.richtext.facet#link", uri: url } ]
      }
    end

    def post_json(ruta, payload, token: nil)
      uri = URI("#{HOST}#{ruta}")
      peticion = Net::HTTP::Post.new(uri)
      peticion["Content-Type"]  = "application/json"
      peticion["Authorization"] = "Bearer #{token}" if token
      peticion.body = payload.to_json

      ejecutar(uri, peticion)
    end

    def ejecutar(uri, peticion)
      respuesta = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 30) do |http|
        http.request(peticion)
      end
      cuerpo = JSON.parse(respuesta.body)
      unless respuesta.is_a?(Net::HTTPSuccess)
        raise "Bluesky: #{cuerpo['error']} — #{cuerpo['message']}"
      end
      cuerpo
    end
  end
end
