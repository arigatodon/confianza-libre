module PostsHelper
  # Cada tipo de publicación tiene una "línea" de color, como las líneas del
  # transporte público: el borde superior de la tarjeta, el ícono y la placa
  # del tipo usan el mismo color. Las clases van escritas completas para que
  # Tailwind las genere (no se arman con interpolación).
  LINEAS = {
    ambar:   { borde: "border-t-secondary",       texto: "text-secondary",         placa: "bg-secondary text-on-secondary" },
    azul:    { borde: "border-t-primary",         texto: "text-primary",           placa: "bg-primary text-on-primary" },
    verde:   { borde: "border-t-tertiary",        texto: "text-tertiary",          placa: "bg-tertiary text-on-tertiary" },
    violeta: { borde: "border-t-linea-violeta",   texto: "text-linea-violeta",     placa: "bg-linea-violeta text-white" },
    noche:   { borde: "border-t-primary-container", texto: "text-primary-container", placa: "bg-primary-container text-on-primary" }
  }.freeze

  KIND_VISUALS = {
    "venta"     => { linea: :ambar,   icon: "shopping_bag" },
    "delivery"  => { linea: :ambar,   icon: "local_shipping" },
    "servicio"  => { linea: :azul,    icon: "handyman" },
    "ayuda"     => { linea: :verde,   icon: "volunteer_activism" },
    "evento"    => { linea: :violeta, icon: "event" },
    "propuesta" => { linea: :violeta, icon: "campaign" },
    "noticia"   => { linea: :violeta, icon: "news" },
    "blog"      => { linea: :noche,   icon: "article" }
  }.freeze

  def post_kind_visual(kind)
    KIND_VISUALS[kind.to_s] || { linea: :azul, icon: "label" }
  end

  def post_kind_linea(kind)
    LINEAS.fetch(post_kind_visual(kind)[:linea])
  end

  def post_kind_border(kind)
    post_kind_linea(kind)[:borde]
  end

  def post_kind_icon(kind)
    post_kind_visual(kind)[:icon]
  end

  def post_kind_text_color(kind)
    post_kind_linea(kind)[:texto]
  end

  # Fondo + texto de la placa del tipo (rótulo de color con letra blanca).
  def post_kind_badge(kind)
    post_kind_linea(kind)[:placa]
  end

  # Formatea una distancia en metros para humanos
  def humanize_distance(meters)
    return nil unless meters
    return "<10m" if meters < 10
    if meters < 1000
      "#{meters.round}m"
    else
      "#{(meters / 1000.0).round(1)} km"
    end
  end
end
