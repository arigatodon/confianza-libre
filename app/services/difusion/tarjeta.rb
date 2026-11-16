require "vips"

module Difusion
  # Genera la tarjeta PNG (1080×1080) de un post para compartir en redes.
  #
  # Privacidad: la tarjeta muestra título, categoría, autor y comuna/ciudad
  # (vía TerritoryResolver) — nunca coordenadas ni dirección exacta.
  #
  # Uso:
  #   png = Difusion::Tarjeta.new(post).render  # => String binario PNG
  class Tarjeta
    ANCHO  = 1080
    ALTO   = 1080
    MARGEN = 80

    VERDE_OSCURO = [ 15, 82, 56 ].freeze    # #0f5238 (theme-color del sitio)
    VERDE_PROFUNDO = [ 9, 53, 36 ].freeze
    BLANCO       = [ 255, 255, 255 ].freeze
    DORADO       = [ 240, 200, 90 ].freeze

    def initialize(post)
      @post = post
    end

    def render
      lienzo = fondo
      lienzo = componer_textos(lienzo)
      lienzo.pngsave_buffer
    end

    private

    attr_reader :post

    # Foto del post oscurecida como fondo — o el fondo generado con IA para
    # posts informativos (imagen_difusion) — o verde institucional si no hay.
    def fondo
      if (imagen = imagen_de_fondo)
        foto = Vips::Image.thumbnail_buffer(imagen.download, ANCHO, height: ALTO, crop: :attention)
        foto = foto.colourspace(:srgb)
        foto = foto.flatten(background: VERDE_OSCURO) if foto.has_alpha?
        # Oscurecer para que el texto blanco sea legible.
        foto.linear([ 0.38, 0.38, 0.38 ], [ 0, 0, 0 ]).cast(:uchar)
      else
        degradado_verde
      end
    rescue Vips::Error, ActiveStorage::Error => e
      Rails.logger.warn("[Difusion::Tarjeta] fondo falló (#{e.class}: #{e.message}), uso degradado")
      degradado_verde
    end

    def imagen_de_fondo
      primera_imagen || (post.imagen_difusion if post.imagen_difusion.attached?)
    end

    def primera_imagen
      post.media.attached? ? post.media.find { |m| m.blob.image? } : nil
    end

    # Degradado vertical entre los dos verdes de marca.
    def degradado_verde
      rampa = Vips::Image.xyz(ANCHO, ALTO)[1].divide(ALTO - 1) # 0..1 por fila
      bandas = (0..2).map do |i|
        rampa.linear([ VERDE_PROFUNDO[i] - VERDE_OSCURO[i] ], [ VERDE_OSCURO[i] ])
      end
      bandas[0].bandjoin(bandas[1..]).cast(:uchar).copy(interpretation: :srgb)
    end

    def componer_textos(lienzo)
      y = MARGEN + 40

      chip = texto(post.kind_label_es.upcase, font: "sans bold 30", color: DORADO, letter_spacing: true)
      lienzo = estampar(lienzo, chip, MARGEN, y)
      y += chip.height + 50

      titulo = texto(post.title, font: "sans bold 72", color: BLANCO, width: ANCHO - MARGEN * 2)
      lienzo = estampar(lienzo, titulo, MARGEN, y)
      y += titulo.height + 40

      if (desc = post.description.presence)
        resumen = texto(desc.truncate(160), font: "sans 36", color: BLANCO,
                        width: ANCHO - MARGEN * 2, opacidad: 0.85)
        lienzo = estampar(lienzo, resumen, MARGEN, y)
      end

      autoria = texto("@#{post.user.username}#{lugar_sufijo}", font: "sans 34", color: BLANCO, opacidad: 0.9)
      lienzo = estampar(lienzo, autoria, MARGEN, ALTO - MARGEN - 130)

      marca = texto("confianza.world", font: "sans bold 44", color: DORADO)
      lienzo = estampar(lienzo, marca, MARGEN, ALTO - MARGEN - 60)

      lienzo
    end

    # " · Ñuñoa" si TerritoryResolver puede resolver la comuna; nada si no.
    def lugar_sufijo
      return "" if post.latitude.blank? || post.longitude.blank?

      resultado = TerritoryResolver.resolve(post.latitude, post.longitude)
      resultado.ok? ? " · #{resultado.territory.name}" : ""
    rescue => e
      Rails.logger.warn("[Difusion::Tarjeta] lugar falló: #{e.message}")
      ""
    end

    # Texto pango → imagen RGBA coloreada lista para componer.
    def texto(contenido, font:, color:, width: ANCHO, opacidad: 1.0, letter_spacing: false)
      markup = ERB::Util.html_escape(contenido)
      markup = %(<span letter_spacing="4096">#{markup}</span>) if letter_spacing
      mascara = Vips::Image.text(markup, font: font, width: width, align: :low)
      mascara = mascara.linear([ opacidad ], [ 0 ]).cast(:uchar) if opacidad < 1.0
      mascara.new_from_image(color).copy(interpretation: :srgb).bandjoin(mascara)
    end

    def estampar(lienzo, capa, x, y)
      lienzo.composite2(capa, :over, x: x, y: y)
    end
  end
end
