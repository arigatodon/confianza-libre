require "net/http"
require "resolv"
require "ipaddr"

# Descarga una imagen desde una URL que nos pasa un tercero (API pública,
# avatar de Google) con las defensas mínimas contra SSRF y abuso:
#
#   - solo http/https,
#   - el host se resuelve ANTES de conectar y se rechaza si apunta a una red
#     privada, loopback o link-local (y se conecta a esa misma IP, para que un
#     DNS que cambie entre resolver y conectar no sirva de nada),
#   - hasta 3 redirecciones, cada una revalidada,
#   - content-type image/* y tamaño acotado.
#
# Uso:
#   img = ImagenRemota.descargar("https://misitio.cl/foto.jpg")
#   post.media.attach(io: img.io, filename: img.filename, content_type: img.content_type)
#
# Lanza ImagenRemota::Error con un mensaje apto para mostrarle al usuario.
class ImagenRemota
  class Error < StandardError; end

  MAX_BYTES        = 8.megabytes
  MAX_REDIRECTS    = 3
  TIMEOUT_SEG      = 10
  TIPOS_PERMITIDOS = %w[image/jpeg image/png image/webp image/gif].freeze

  REDES_PRIVADAS = %w[
    0.0.0.0/8 10.0.0.0/8 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16
    100.64.0.0/10 ::1/128 fc00::/7 fe80::/10 ::ffff:0:0/96
  ].map { |r| IPAddr.new(r) }.freeze

  Imagen = Struct.new(:io, :filename, :content_type, keyword_init: true)

  def self.descargar(url) = new.descargar(url)

  def self.ip_privada?(ip)
    addr = IPAddr.new(ip.to_s)
    REDES_PRIVADAS.any? { |red| red.include?(addr) }
  rescue IPAddr::Error
    true
  end

  def descargar(url, redirecciones = 0)
    uri = parsear(url)
    ip  = resolver(uri.host)

    respuesta, bytes = pedir(uri, ip)

    case respuesta
    when Net::HTTPRedirection
      raise Error, "la imagen redirige demasiadas veces" if redirecciones >= MAX_REDIRECTS
      destino = URI.join(uri, respuesta["location"].to_s).to_s
      descargar(destino, redirecciones + 1)
    when Net::HTTPSuccess
      construir(uri, respuesta, bytes)
    else
      raise Error, "no pudimos descargar la imagen (HTTP #{respuesta.code})"
    end
  rescue Timeout::Error, Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError, OpenSSL::SSL::SSLError => e
    raise Error, "no pudimos descargar la imagen (#{e.class.name.demodulize})"
  end

  private

  def parsear(url)
    uri = URI.parse(url.to_s.strip)
    raise Error, "la URL de la imagen debe empezar con http:// o https://" unless uri.is_a?(URI::HTTP) && uri.host.present?
    uri
  rescue URI::InvalidURIError
    raise Error, "la URL de la imagen no es válida"
  end

  def resolver(host)
    direcciones = Resolv.getaddresses(host)
    raise Error, "no pudimos resolver el host de la imagen" if direcciones.empty?
    raise Error, "la URL de la imagen apunta a una red no permitida" if direcciones.any? { |ip| self.class.ip_privada?(ip) }
    direcciones.first
  end

  # Lee el cuerpo en streaming y corta apenas se pasa del máximo, para que un
  # archivo gigante no llene la memoria antes de que lo rechacemos.
  def pedir(uri, ip)
    http = Net::HTTP.new(uri.host, uri.port)
    http.ipaddr       = ip
    http.use_ssl      = uri.scheme == "https"
    http.open_timeout = TIMEOUT_SEG
    http.read_timeout = TIMEOUT_SEG

    peticion = Net::HTTP::Get.new(uri)
    peticion["User-Agent"] = "Confianza (+https://confianza.world)"
    peticion["Accept"]     = "image/*"

    cuerpo = StringIO.new
    respuesta = http.start do |conexion|
      conexion.request(peticion) do |resp|
        next unless resp.is_a?(Net::HTTPSuccess)
        if resp["content-length"].to_i > MAX_BYTES
          raise Error, "la imagen supera el máximo de #{MAX_BYTES / 1.megabyte} MB"
        end
        resp.read_body do |trozo|
          cuerpo.write(trozo)
          raise Error, "la imagen supera el máximo de #{MAX_BYTES / 1.megabyte} MB" if cuerpo.length > MAX_BYTES
        end
      end
    end
    [ respuesta, cuerpo.string ]
  end

  def construir(uri, respuesta, bytes)
    tipo = respuesta["content-type"].to_s.split(";").first.to_s.strip.downcase
    raise Error, "la URL no apunta a una imagen (jpg, png, webp o gif)" unless TIPOS_PERMITIDOS.include?(tipo)

    raise Error, "la imagen está vacía" if bytes.empty?

    nombre = File.basename(uri.path.to_s).presence || "imagen"
    nombre = "#{nombre}.#{tipo.split('/').last}" unless nombre.include?(".")

    Imagen.new(io: StringIO.new(bytes), filename: nombre.first(120), content_type: tipo)
  end
end
