require "net/http"

module Difusion
  # Publica la tarjeta de un post en Instagram vía Graph API (cuenta Business).
  #
  # A diferencia de Telegram/Bluesky, Instagram NO acepta los bytes de la imagen:
  # exige una URL pública. Usamos la de la tarjeta (tarjeta_url:), que Meta
  # descarga desde nuestro servidor — por eso ignora tarjeta_png:.
  #
  # El alta es en dos pasos: 1) crear un "media container" con image_url +
  # caption, 2) publicarlo (media_publish) con el creation_id devuelto.
  #
  # Variables de entorno:
  #   INSTAGRAM_USER_ID      — IG User ID de la cuenta Business
  #   INSTAGRAM_ACCESS_TOKEN — token de larga duración (Page/IG)
  class Instagram
    NETWORK = "instagram"
    HOST    = "https://graph.facebook.com"
    VERSION = "v21.0"

    # Meta descarga y procesa la imagen de forma asíncrona tras crear el
    # contenedor. Hay que esperar a que pase a FINISHED antes de publicar, o
    # media_publish falla con "Media ID is not available".
    INTENTOS_MAX = 20
    ESPERA_SEG   = 3

    # Invitación que va como primer comentario del post: en Instagram los
    # links del caption no son clickeables, así que el camino real es la bio.
    COMENTARIO_CTA = "Para ver esta publicación y más como esta, entra al link en la bio 🌱"

    def self.configurada? = ENV["INSTAGRAM_USER_ID"].present? && ENV["INSTAGRAM_ACCESS_TOKEN"].present?

    # Devuelve el media id publicado. Lanza si Meta responde error.
    # mencion: handle de Instagram del autor (sin arroba). Opcional: si el autor
    # no lo declaró, la publicación sale igual, solo que sin etiquetarlo.
    def publicar(tarjeta_png:, texto:, url:, tarjeta_url: nil, mencion: nil)
      raise "Instagram: falta tarjeta_url (URL pública de la imagen)" if tarjeta_url.blank?

      creation_id = crear_contenedor(image_url: tarjeta_url, caption: caption_de(texto, mencion))
      esperar_contenedor(creation_id)
      media_id = publicar_contenedor(creation_id)
      comentar(media_id)
      media_id
    end

    private

    # En Instagram "@algo" etiqueta cuentas reales: un arroba venido del título o
    # del username de Confianza apuntaría a un desconocido, así que se limpian
    # todos. La única mención que se agrega es la del autor, y solo si declaró su
    # Instagram en la vitrina — ahí el etiquetado sí es correcto y además le llega
    # la notificación para compartir la publicación en sus historias.
    # Tampoco va la URL cruda (no es clickeable): la invitación sale en el comentario.
    def caption_de(texto, mencion = nil)
      limpio = texto.tr("@", "")
      mencion.present? ? "#{limpio} (@#{mencion})" : limpio
    end

    # El comentario no puede voltear una publicación que ya salió bien:
    # si falla, se loguea y listo.
    def comentar(media_id)
      post_form("#{media_id}/comments", message: COMENTARIO_CTA)
    rescue => e
      Rails.logger.warn("[Difusion::Instagram] comentario falló en #{media_id}: #{e.message}")
    end

    def crear_contenedor(image_url:, caption:)
      respuesta = post_form("#{usuario}/media", image_url: image_url, caption: caption)
      respuesta.fetch("id")
    end

    # Sondea el estado del contenedor hasta que Meta termine de bajar la imagen.
    def esperar_contenedor(creation_id)
      INTENTOS_MAX.times do
        estado = get_field(creation_id, "status_code")
        return if estado == "FINISHED"
        raise "Instagram: contenedor en estado #{estado}" if %w[ERROR EXPIRED].include?(estado)

        sleep ESPERA_SEG
      end
      raise "Instagram: el contenedor no quedó listo tras #{INTENTOS_MAX * ESPERA_SEG}s"
    end

    def publicar_contenedor(creation_id)
      respuesta = post_form("#{usuario}/media_publish", creation_id: creation_id)
      respuesta.fetch("id")
    end

    def usuario = ENV["INSTAGRAM_USER_ID"]

    def get_field(id, campo)
      uri = URI("#{HOST}/#{VERSION}/#{id}")
      uri.query = URI.encode_www_form(fields: campo, access_token: ENV["INSTAGRAM_ACCESS_TOKEN"])

      respuesta = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 30) do |http|
        http.request(Net::HTTP::Get.new(uri))
      end

      cuerpo = JSON.parse(respuesta.body)
      unless respuesta.is_a?(Net::HTTPSuccess)
        error = cuerpo.dig("error", "message") || respuesta.code
        raise "Instagram: #{error}"
      end
      cuerpo[campo]
    end

    def post_form(ruta, **campos)
      uri = URI("#{HOST}/#{VERSION}/#{ruta}")
      peticion = Net::HTTP::Post.new(uri)
      peticion.set_form_data(campos.merge(access_token: ENV["INSTAGRAM_ACCESS_TOKEN"]))

      respuesta = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 30) do |http|
        http.request(peticion)
      end

      cuerpo = JSON.parse(respuesta.body)
      unless respuesta.is_a?(Net::HTTPSuccess)
        error = cuerpo.dig("error", "message") || respuesta.code
        raise "Instagram: #{error}"
      end
      cuerpo
    end
  end
end
