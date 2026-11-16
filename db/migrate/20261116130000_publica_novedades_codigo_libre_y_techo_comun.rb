# Migración de datos: publica en /novedades el código libre y el techo común.
# Sale junto con el deploy de esos cambios. Idempotente por título.
class PublicaNovedadesCodigoLibreYTechoComun < ActiveRecord::Migration[8.1]
  NOVEDADES = [
    {
      titulo: "El código de Confianza ahora es libre",
      cuerpo: <<~TEXTO
        Desde hoy, el código que hace funcionar Confianza es público, con licencia AGPL: github.com/arigatodon/confianza-libre

        ¿Por qué importa? Si las reglas de la economía las decide la comunidad, el código que las aplica también tiene que estar a la vista. Así cualquiera puede comprobar que el sistema hace lo que dice, proponer mejoras o levantar una red propia. Y nadie, ni siquiera quienes mantenemos el proyecto, puede cambiar las reglas a escondidas.

        Lo que no se publica: datos de las personas ni la configuración privada del servidor. Tu información sigue igual de protegida.

        También sumamos al manifiesto una sección nueva, «Lo que viene», sobre por qué esto importa ahora.
      TEXTO
    },
    {
      titulo: "Todos tenemos el mismo techo",
      cuerpo: <<~TEXTO
        Cambiamos una regla de fondo de la economía. Antes, mientras más nivel tenías, más créditos podías acumular: del nivel 1 al 5, el techo crecía 10.000 veces. Eso contradecía lo que creemos: la reputación no debería convertirse en riqueza.

        Desde ahora, el techo es el mismo para todas las personas: 5.000 C. Lo que pase de ahí va al fondo de tu comuna.

        Tu nivel sigue importando, pero para otra cosa: cuánto te fía la comunidad (en negativo, hasta −100 C en el nivel 1 y hasta −2.000 C en el nivel 5) y cuánto puedes mover en un solo intercambio.

        Además, cualquier persona con su email verificado puede proponer cambios de reglas. El techo común también se puede cambiar, con una propuesta votada por toda la red.

        La confianza te da crédito, no riqueza. Las reglas completas están en confianza.world/economia.
      TEXTO
    }
  ].freeze

  def up
    autor = User.find_by(username: "igor") || User.order(:created_at).first
    unless autor
      say "Sin usuarios todavía — novedades no publicadas."
      return
    end

    NOVEDADES.each do |n|
      next if Announcement.exists?(title: n[:titulo])

      Announcement.create!(user: autor, title: n[:titulo], body: n[:cuerpo], kind: :cambio, published_at: Time.current)
      say "Novedad publicada: #{n[:titulo]}"
    end
  end

  def down
    Announcement.where(title: NOVEDADES.map { |n| n[:titulo] }).destroy_all
  end
end
