require "vips"
require "rqrcode"

module Vitrina
  # Genera la tarjeta QR imprimible (1080×1350) de la vitrina de un usuario:
  # para pegar en el local, el puesto de feria o repartir. El QR apunta al
  # perfil público (confianza.world/username).
  #
  # Uso:
  #   png = Vitrina::TarjetaQr.new(user, url: profile_url).render  # => String PNG
  #
  # `destino` (opcional) es lo que codifica el QR si difiere del link impreso:
  # así el QR lleva utm para contar escaneos y el texto sigue limpio.
  class TarjetaQr
    ANCHO  = 1080
    ALTO   = 1350
    MARGEN = 80

    VERDE_OSCURO   = [ 15, 82, 56 ].freeze   # #0f5238
    VERDE_PROFUNDO = [ 9, 53, 36 ].freeze
    BLANCO         = [ 255, 255, 255 ].freeze
    DORADO         = [ 240, 200, 90 ].freeze

    CAJA_QR = 760  # lado de la caja blanca
    QR      = 640  # lado del QR dentro de la caja

    def initialize(user, url:, destino: nil)
      @user = user
      @url = url
      @destino = destino || url
    end

    def render
      lienzo = degradado_verde
      lienzo = componer_textos_superiores(lienzo)
      lienzo = estampar_qr(lienzo)
      lienzo = componer_textos_inferiores(lienzo)
      lienzo.pngsave_buffer
    end

    private

    attr_reader :user, :url, :destino

    def degradado_verde
      rampa = Vips::Image.xyz(ANCHO, ALTO)[1].divide(ALTO - 1)
      bandas = (0..2).map do |i|
        rampa.linear([ VERDE_PROFUNDO[i] - VERDE_OSCURO[i] ], [ VERDE_OSCURO[i] ])
      end
      bandas[0].bandjoin(bandas[1..]).cast(:uchar).copy(interpretation: :srgb)
    end

    def componer_textos_superiores(lienzo)
      y = MARGEN

      nombre = texto("@#{user.username}", font: "sans bold 64", color: BLANCO, width: ANCHO - MARGEN * 2)
      lienzo = centrar(lienzo, nombre, y)
      y += nombre.height + 24

      if user.headline.present?
        rubro = texto(user.headline.truncate(60), font: "sans 38", color: BLANCO,
                      width: ANCHO - MARGEN * 2, opacidad: 0.9)
        lienzo = centrar(lienzo, rubro, y)
      end

      lienzo
    end

    def estampar_qr(lienzo)
      caja = Vips::Image.black(CAJA_QR, CAJA_QR).new_from_image(BLANCO).cast(:uchar).copy(interpretation: :srgb)
      caja = caja.composite2(imagen_qr, :over, x: (CAJA_QR - QR) / 2, y: (CAJA_QR - QR) / 2)
      lienzo.composite2(caja, :over, x: (ANCHO - CAJA_QR) / 2, y: 340)
    end

    def imagen_qr
      png = RQRCode::QRCode.new(destino, level: :m).as_png(size: QR, border_modules: 0).to_s
      Vips::Image.new_from_buffer(png, "").colourspace(:srgb)
    end

    def componer_textos_inferiores(lienzo)
      llamado = texto("Escanea y mira mi vitrina", font: "sans bold 44", color: DORADO)
      lienzo = centrar(lienzo, llamado, 340 + CAJA_QR + 60)

      marca = texto(url_legible, font: "sans bold 40", color: BLANCO)
      centrar(lienzo, marca, ALTO - MARGEN - marca.height)
    end

    def url_legible
      url.sub(%r{\Ahttps?://(www\.)?}, "")
    end

    def texto(contenido, font:, color:, width: ANCHO, opacidad: 1.0)
      mascara = Vips::Image.text(ERB::Util.html_escape(contenido), font: font, width: width, align: :centre)
      mascara = mascara.linear([ opacidad ], [ 0 ]).cast(:uchar) if opacidad < 1.0
      mascara.new_from_image(color).copy(interpretation: :srgb).bandjoin(mascara)
    end

    def centrar(lienzo, capa, y)
      lienzo.composite2(capa, :over, x: (ANCHO - capa.width) / 2, y: y)
    end
  end
end
