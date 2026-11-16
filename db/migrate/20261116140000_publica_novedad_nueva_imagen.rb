# Migración de datos: publica en /novedades la imagen nueva y la explicación
# simple. Sale junto con el deploy de la rama identidad-visual. Idempotente por título.
class PublicaNovedadNuevaImagen < ActiveRecord::Migration[8.1]
  TITULO = "Confianza cambia de cara: más clara, más de todos".freeze

  CUERPO = <<~TEXTO.freeze
    Confianza es infraestructura del barrio, y queríamos que se viera así: como un buen letrero de paradero o el toldo azul de la feria, algo que cualquiera entiende de un vistazo.

    Logo nuevo: dos mitades iguales frente a frente, las dos partes de cada intercambio, y al centro un punto amarillo: lo que compartimos, el barrio y su fondo común.

    Más fácil de leer: letra un poco más grande y con mejor contraste, botones más grandes para el dedo y colores que se distinguen al sol.

    Cada tipo de publicación tiene su color, como las líneas del metro: ámbar para ventas, azul para servicios, verde para ayuda y violeta para eventos.

    Más liviana: la página carga bastante menos datos, algo que se nota en celulares con plan de datos.

    Se explica más simple: menos números y menos texto. Cada pantalla dice qué es y qué puedes hacer ahora. Las reglas exactas siguen en confianza.world/economia.

    En la portada ya no mostramos personas ni intercambios inventados: lo que es un ejemplo dice «Ejemplo».

    Si algo se ve raro en tu celular, cuéntanos con el botón del megáfono.
  TEXTO

  def up
    return if Announcement.exists?(title: TITULO)

    autor = User.find_by(username: "igor") || User.order(:created_at).first
    unless autor
      say "Sin usuarios todavía — novedad no publicada."
      return
    end

    Announcement.create!(user: autor, title: TITULO, body: CUERPO, kind: :cambio, published_at: Time.current)
    say "Novedad publicada: #{TITULO}"
  end

  def down
    Announcement.where(title: TITULO).destroy_all
  end
end
