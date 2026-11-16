require "net/http"
require "base64"

module Difusion
  # Genera con IA el fondo de la tarjeta para publicaciones informativas
  # (noticia/blog) que no traen foto propia — así las novedades salen a las
  # redes con una imagen, como cualquier publicación de un vecino, en vez del
  # degradado verde.
  #
  # Usa "Nano Banana 2 Lite" (gemini-3.1-flash-lite-image) de la Gemini API:
  # el modelo liviano de imagen de Google — rápido y barato, suficiente para
  # un fondo que después se oscurece y recibe el texto encima.
  #
  # Variables de entorno:
  #   GOOGLE_API_KEY — API key de Google AI Studio
  class ImagenIa
    HOST   = "https://generativelanguage.googleapis.com"
    MODELO = "gemini-3.1-flash-lite-image"

    Resultado = Data.define(:bytes, :mime_type)

    def self.configurada? = ENV["GOOGLE_API_KEY"].present?

    # Devuelve un Resultado con los bytes de la imagen. Lanza si la API
    # responde error o no trae imagen (el caller decide si es fatal).
    def generar(post)
      respuesta = generate_content(prompt_para(post))
      parte = respuesta.dig("candidates", 0, "content", "parts")&.find { |p| p["inlineData"] }
      raise "ImagenIa: la respuesta no trajo imagen" if parte.nil?

      Resultado.new(
        bytes:     Base64.decode64(parte.dig("inlineData", "data")),
        mime_type: parte.dig("inlineData", "mimeType") || "image/png"
      )
    end

    private

    # La tarjeta oscurece el fondo y superpone título y descripción, así que
    # acá lo importante es: ambiente de comunidad, y NADA de texto ni logos.
    def prompt_para(post)
      <<~PROMPT.squish
        Fotografía editorial cálida y luminosa para ilustrar una noticia de una
        red social comunitaria de barrio en Latinoamérica.
        Tema de la noticia: #{post.title}. #{post.description.to_s.truncate(200)}
        Escena cotidiana de vecinos, ferias, calles arboladas o manos que cooperan,
        con tonos verdes naturales y dorados suaves.
        Estrictamente sin texto, sin letras, sin números, sin logos, sin marcas
        de agua y sin pantallas con interfaces.
      PROMPT
    end

    def generate_content(prompt)
      uri = URI("#{HOST}/v1beta/models/#{MODELO}:generateContent")
      peticion = Net::HTTP::Post.new(uri)
      peticion["x-goog-api-key"] = ENV["GOOGLE_API_KEY"]
      peticion["Content-Type"]   = "application/json"
      peticion.body = {
        contents: [ { parts: [ { text: prompt } ] } ],
        generationConfig: {
          responseModalities: [ "IMAGE" ],
          imageConfig: { aspectRatio: "1:1" }
        }
      }.to_json

      # La generación tarda varios segundos; corre en un job, no en requests.
      respuesta = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 120) do |http|
        http.request(peticion)
      end

      cuerpo = JSON.parse(respuesta.body)
      unless respuesta.is_a?(Net::HTTPSuccess)
        error = cuerpo.dig("error", "message") || respuesta.code
        raise "ImagenIa: #{error}"
      end
      cuerpo
    end
  end
end
