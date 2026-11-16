# Difunde un post (con consentimiento del autor) a las redes sociales de
# Confianza. Idempotente: el índice único de social_broadcasts garantiza un
# envío por red, así que se puede reencolar sin duplicar publicaciones.
class DifundirPostJob < ApplicationJob
  queue_as :default

  ADAPTADORES = [ Difusion::Telegram, Difusion::Bluesky, Difusion::Instagram, Difusion::Facebook ].freeze

  def perform(post_id)
    post = Post.find_by(id: post_id)
    return if post.nil? || !post.difundir? || !post.published? || post.hidden_by_moderation?

    redes = ADAPTADORES.select(&:configurada?)
    return if redes.empty?

    asegurar_imagen_ia(post)

    tarjeta     = Difusion::Tarjeta.new(post).render
    texto       = texto_para(post)
    url         = url_del(post)
    tarjeta_url = tarjeta_url_del(post)

    redes.each do |adaptador|
      difusion = post.social_broadcasts.create_or_find_by!(network: adaptador::NETWORK)
      next if difusion.status == "enviado"

      begin
        # Solo Instagram sabe qué hacer con una mención: es la única red donde el
        # arroba etiqueta a una persona de verdad y le llega la notificación.
        extra = adaptador == Difusion::Instagram ? { mencion: post.user.instagram_handle } : {}

        external_id = adaptador.new.publicar(
          tarjeta_png: tarjeta, texto: texto, url: url, tarjeta_url: tarjeta_url, **extra
        )
        difusion.marcar_enviado!(external_id)
      rescue => e
        difusion.marcar_error!(e.message)
        Rails.logger.error("[DifundirPostJob] #{adaptador::NETWORK} post=#{post.id}: #{e.message}")
      end
    end
  end

  # Kinds informativos: novedades del proyecto y notas largas, que casi nunca
  # traen foto — los únicos donde generamos fondo con IA.
  KINDS_INFORMATIVOS = %w[noticia blog].freeze

  private

  # Posts informativos sin foto: generar el fondo con IA una sola vez y
  # dejarlo adjunto, para que la tarjeta salga con imagen como cualquier
  # publicación con foto. Si la generación falla, la tarjeta cae sola al
  # degradado azul de marca — nunca bloquea la difusión.
  def asegurar_imagen_ia(post)
    return unless post.kind.in?(KINDS_INFORMATIVOS)
    return if post.imagen_difusion.attached?
    return if post.media.attached? && post.media.any? { |m| m.blob.image? }
    return unless Difusion::ImagenIa.configurada?

    resultado = Difusion::ImagenIa.new.generar(post)
    extension = resultado.mime_type.split("/").last
    post.imagen_difusion.attach(
      io:           StringIO.new(resultado.bytes),
      filename:     "difusion-#{post.id}.#{extension}",
      content_type: resultado.mime_type
    )
  rescue => e
    Rails.logger.warn("[DifundirPostJob] imagen IA falló post=#{post.id}: #{e.message}")
  end

  def url_del(post)
    Rails.application.routes.url_helpers.post_url(post, **host_opts)
  end

  # URL pública de la tarjeta PNG: la usa Instagram, que descarga la imagen
  # en vez de recibir los bytes. El helper omite el ".png" (es el formato por
  # defecto de la ruta), así que lo agregamos para que Meta lo reciba explícito.
  def tarjeta_url_del(post)
    Rails.application.routes.url_helpers.tarjeta_post_url(post, **host_opts) + ".png"
  end

  def host_opts
    opciones = Rails.application.routes.default_url_options
    {
      host:     opciones[:host] || "confianza.world",
      protocol: opciones[:protocol] || "https"
    }
  end

  def texto_para(post)
    partes = [ "#{post.kind_label_es}: #{post.title}" ]
    partes << "por @#{post.user.username}"
    partes.join(" · ")
  end
end
