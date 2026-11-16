# Presentación de la economía en palabras simples (ver "Cómo escribimos" en
# docs/identidad-visual.md): pasos en vez de tablas, estrellas en vez de
# decimales. No calcula nada: solo traduce lo que ya entregan los servicios.
module EconomiaHelper
  VERIFICACION_PASO = {
    "email"    => [ "Verifica tu email", "Verificaste tu email" ],
    "phone"    => [ "Consigue el aval de tus vecinos", "Tienes el aval de tus vecinos" ],
    "identity" => [ "Verifica tu identidad", "Verificaste tu identidad" ]
  }.freeze

  # "100 C" con espacio duro: el número y la C nunca quedan en líneas distintas.
  def creditos(cantidad)
    "#{number_with_delimiter(cantidad.to_i)}\u00a0C"
  end

  # "1 intercambio" / "3 intercambios". `pluralize` no sirve: con el locale
  # :es no hay reglas de inflexión y devuelve siempre el singular.
  def contar(cantidad, singular, plural = "#{singular}s")
    "#{number_with_delimiter(cantidad)} #{cantidad.to_i == 1 ? singular : plural}"
  end

  # Filas de CreditLimitCalculator#progress_to_next_level → pasos en palabras.
  # Cada paso: { texto:, hecho: }. Primero lo que falta, después lo hecho.
  def pasos_para_subir(progresion)
    Array(progresion).map { |fila| paso_en_palabras(fila) }.sort_by { |p| p[:hecho] ? 1 : 0 }
  end

  def paso_en_palabras(fila)
    hecho  = fila[:met]
    faltan = fila[:required].is_a?(Numeric) ? (fila[:required] - fila[:current].to_f).ceil : nil

    texto =
      case fila[:label]
      when "Interacciones completadas"
        hecho ? "Ya cerraste #{contar(fila[:current], 'intercambio')}" : "Cierra #{contar(faltan, 'intercambio')} más"
      when "Contrapartes distintas"
        hecho ? "Ya intercambiaste con #{contar(fila[:current], 'persona distinta', 'personas distintas')}" :
                "Intercambia con #{contar(faltan, 'persona nueva', 'personas nuevas')}"
      when "Trust score"
        hecho ? "Tus reseñas son buenas" : "Que tus reseñas lleguen a #{estrellas_en_palabras(fila[:required])}"
      when "Antigüedad (días)"
        hecho ? "Ya llevas #{contar(fila[:current], 'día')} en la red" : "Espera #{contar(faltan, 'día')} más"
      when "Verificación"
        pendiente, listo = VERIFICACION_PASO.fetch(fila[:required].to_s, [ "Verifica tu cuenta", "Cuenta verificada" ])
        hecho ? listo : pendiente
      else
        fila[:label]
      end

    { texto: texto, hecho: hecho }
  end

  # 3.5 → "3 estrellas y media", 4.0 → "4 estrellas", 4.3 → "más de 4 estrellas".
  def estrellas_en_palabras(valor)
    entero = valor.to_f.floor
    resto  = (valor.to_f - entero).round(2)
    base   = contar(entero, "estrella")
    if resto.zero?      then base
    elsif resto == 0.5  then "#{base} y media"
    else                     "más de #{base}"
    end
  end

  # Estrellas dibujadas (0..5), redondeadas a la media estrella hacia abajo.
  # El número va solo para lectores de pantalla.
  def estrellas(valor, clase: "text-secondary", tamano: 18)
    v = valor.to_f.clamp(0, 5)
    llenas = v.floor
    media  = (v - llenas) >= 0.5 ? 1 : 0
    vacias = 5 - llenas - media
    iconos = ([ "star" ] * llenas) + ([ "star_half" ] * media) + ([ "star" ] * vacias)
    tag.span(class: "inline-flex items-center #{clase}", role: "img",
             "aria-label": "#{number_with_precision(v, precision: 1, strip_insignificant_zeros: true)} de 5 estrellas") do
      safe_join(iconos.each_with_index.map do |icono, i|
        lleno = i < llenas + media
        tag.span(icono, class: "material-symbols-outlined #{"icon-filled" if lleno} #{"opacity-30" unless lleno}",
                        style: "font-size:#{tamano}px", "aria-hidden": "true")
      end)
    end
  end
end
