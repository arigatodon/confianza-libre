# Migración de datos: publica la novedad de la Vitrina 2.0 en /novedades.
# Va como migración (y no por consola) para que salga en producción junto con
# el deploy de la feature — ni antes ni después. Idempotente por título.
class PublicaNovedadVitrina2 < ActiveRecord::Migration[8.1]
  TITULO = "Tu vitrina, ahora de verdad tuya".freeze

  CUERPO = <<~TEXTO.freeze
    Tu perfil en Confianza siempre pudo ser tu vitrina pública. Desde hoy, además, se arma según tu rubro y se viste con tus colores.

    Plantillas por rubro. Elige qué eres: tienda, oficio, comida, eventos, profesional o comunidad. Si tienes un almacén, tu catálogo aparece primero; si eres gásfiter, primero aparece tu reputación — que es lo que tu cliente quiere ver. Cada plantilla también renombra tus publicaciones: «Catálogo», «Menú», «Agenda», según corresponda.

    Botón de WhatsApp. Pones tu número y quien visite tu vitrina te escribe con un toque. El botón dice lo que corresponde a tu rubro: «Pedir ahora», «Pedir presupuesto», «Pedir por WhatsApp».

    Foto de portada, color propio, horario y links. Tu local o tu trabajo arriba de todo, cuatro colores para elegir el tono, cuándo atiendes y dónde más encontrarte (Instagram, Facebook, tu web).

    Tu QR para imprimir. Descarga la tarjeta con el QR de tu vitrina, imprímela y pégala en tu local, tu puesto o la feria. Quien la escanee cae directo en tu vitrina, con tu catálogo, tu WhatsApp y tu reputación a la vista.

    Y un consejo: usa confianza.world/tu_nombre como el link en la bio de tu Instagram. En Instagram muestras; en Confianza te contactan, vendes y tu reputación queda registrada.

    Todo se configura en Ajustes → Tu vitrina. Cinco minutos y queda lista.
  TEXTO

  def up
    autor = User.find_by(username: "igor") ||
            User.order(:created_at).first
    unless autor
      say "Sin usuarios todavía — novedad no publicada (se puede crear por consola después)."
      return
    end

    return if Announcement.exists?(title: TITULO)

    Announcement.create!(
      user: autor,
      title: TITULO,
      body: CUERPO,
      kind: :cambio,
      published_at: Time.current
    )
    say "Novedad publicada: #{TITULO}"
  end

  def down
    Announcement.find_by(title: TITULO)&.destroy
  end
end
