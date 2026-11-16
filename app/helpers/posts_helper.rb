module PostsHelper
  KIND_VISUALS = {
    "venta"     => { color: "secondary",         icon: "shopping_bag" },
    "delivery"  => { color: "secondary",         icon: "local_shipping" },
    "servicio"  => { color: "primary-container", icon: "handyman" },
    "ayuda"     => { color: "primary-container", icon: "volunteer_activism" },
    "evento"    => { color: "tertiary",          icon: "event" },
    "propuesta" => { color: "tertiary",          icon: "campaign" },
    "noticia"   => { color: "tertiary",          icon: "news" },
    "blog"      => { color: "primary",           icon: "article" }
  }.freeze

  def post_kind_visual(kind)
    KIND_VISUALS[kind.to_s] || { color: "primary", icon: "label" }
  end

  def post_kind_border(kind)
    "border-#{post_kind_visual(kind)[:color]}"
  end

  def post_kind_icon(kind)
    post_kind_visual(kind)[:icon]
  end

  def post_kind_text_color(kind)
    "text-#{post_kind_visual(kind)[:color]}"
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
