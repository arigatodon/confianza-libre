require "net/http"

module Difusion
  # Publica la tarjeta de un post en un canal de Telegram vía Bot API.
  #
  # Variables de entorno:
  #   TELEGRAM_BOT_TOKEN — token del bot (BotFather)
  #   TELEGRAM_CHAT_ID   — id del canal (ej: "@confianza_chile" o "-100123…")
  class Telegram
    NETWORK = "telegram"

    def self.configurada? = ENV["TELEGRAM_BOT_TOKEN"].present? && ENV["TELEGRAM_CHAT_ID"].present?

    # Devuelve el message_id del envío. Lanza si Telegram responde error.
    # tarjeta_url: se ignora (Telegram recibe los bytes de la imagen).
    def publicar(tarjeta_png:, texto:, url:, tarjeta_url: nil)
      uri = URI("https://api.telegram.org/bot#{ENV['TELEGRAM_BOT_TOKEN']}/sendPhoto")

      # .b: Net::HTTP concatena las partes del multipart en un solo buffer y
      # revienta al mezclar texto UTF-8 (tildes, "·") con el PNG binario.
      # Relabelar a BINARY manda los mismos bytes sin el conflicto.
      form = [
        [ "chat_id", ENV["TELEGRAM_CHAT_ID"] ],
        [ "caption", "#{texto}\n\n#{url}".b ],
        [ "photo", tarjeta_png, { filename: "tarjeta.png", content_type: "image/png" } ]
      ]

      respuesta = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 30) do |http|
        peticion = Net::HTTP::Post.new(uri)
        peticion.set_form(form, "multipart/form-data")
        http.request(peticion)
      end

      cuerpo = JSON.parse(respuesta.body)
      raise "Telegram: #{cuerpo['description'] || respuesta.code}" unless cuerpo["ok"]

      cuerpo.dig("result", "message_id").to_s
    end
  end
end
