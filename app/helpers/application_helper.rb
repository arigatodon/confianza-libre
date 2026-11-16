module ApplicationHelper
  SITE_NAME        = "Confianza".freeze
  SITE_DESCRIPTION = "Red social geolocalizada de reputación y créditos comunitarios. Construye tu reputación ayudando a tus vecinos.".freeze
  # Imagen OG de marca (1200×630). Fallback cuando la página no tiene imagen propia.
  DEFAULT_OG_IMAGE = "/og-default.png".freeze

  # Renderiza meta tags SEO + Open Graph + Twitter Card.
  # Pasar title, description, og_type ("website" | "article" | "profile"),
  # image_url (absoluta), canonical (absoluta). Si no se pasa image_url se usa
  # la imagen de marca por defecto, así los enlaces compartidos nunca salen pelados.
  def seo_meta_tags(title:, description:, og_type: "website", image_url: nil, canonical: nil)
    description = description.to_s.gsub(/\s+/, " ").strip.truncate(300, separator: " ")
    title_full = title.present? ? "#{title} · #{SITE_NAME}" : SITE_NAME
    image_url  = absolute_url(image_url.presence || DEFAULT_OG_IMAGE)

    tags = []
    tags << tag.meta(name: "description", content: description) if description.present?
    tags << tag.link(rel: "canonical", href: canonical) if canonical.present?

    tags << tag.meta(property: "og:site_name", content: SITE_NAME)
    tags << tag.meta(property: "og:type",      content: og_type)
    tags << tag.meta(property: "og:title",     content: title_full)
    tags << tag.meta(property: "og:description", content: description) if description.present?
    tags << tag.meta(property: "og:url",       content: canonical) if canonical.present?
    tags << tag.meta(property: "og:image",     content: image_url) if image_url.present?

    tags << tag.meta(name: "twitter:card",  content: image_url.present? ? "summary_large_image" : "summary")
    tags << tag.meta(name: "twitter:title", content: title_full)
    tags << tag.meta(name: "twitter:description", content: description) if description.present?
    tags << tag.meta(name: "twitter:image", content: image_url) if image_url.present?

    safe_join(tags, "\n")
  end

  # URL absoluta de la imagen OG de marca por defecto.
  def default_og_image_url
    absolute_url(DEFAULT_OG_IMAGE)
  end

  # Convierte una ruta relativa ("/foo", "/rails/active_storage/...") en URL
  # absoluta usando el host del request. Las URLs ya absolutas se devuelven
  # tal cual. OG, Twitter Cards y JSON-LD exigen URLs absolutas.
  def absolute_url(url)
    return url if url.blank? || url.to_s.start_with?("http://", "https://")
    return url unless request

    URI.join(request.base_url, url.to_s).to_s
  end

  # Renderiza un bloque JSON-LD (datos estructurados schema.org). `data` es un
  # Hash; #to_json escapa < > & a \uXXXX (escape_html_entities_in_json), así que
  # es seguro inyectarlo dentro de <script> aunque incluya contenido de usuario.
  def json_ld_tag(data)
    return "" if data.blank?

    content_tag(:script, raw(data.to_json), type: "application/ld+json")
  end

  # Mapea el kind de un Post al @type de schema.org más representativo.
  POST_SCHEMA_TYPES = {
    "venta"     => "Product",
    "delivery"  => "Product",
    "servicio"  => "Service",
    "ayuda"     => "Service",
    "evento"    => "Event",
    "propuesta" => "CreativeWork",
    "noticia"   => "Article",
    "blog"      => "Article"
  }.freeze

  def post_schema_type(post)
    POST_SCHEMA_TYPES[post.kind.to_s] || "CreativeWork"
  end

  VERIFICATION_LEVEL_LABELS_ES = {
    "unverified" => "Sin verificar",
    "email"      => "Email verificado",
    "phone"      => "Avalado por vecinos",
    "identity"   => "Identidad verificada"
  }.freeze

  def verification_level_label_es(user)
    VERIFICATION_LEVEL_LABELS_ES[user&.verification_level.to_s] || "Sin verificar"
  end

  # Renderiza un link "Reportar" para cualquier reportable (Post/Comment/Message/User).
  # Se oculta cuando no hay sesión o el current_user es el autor del contenido.
  def report_link(reportable, label: "Reportar", classes: nil)
    return "" unless authenticated?

    author_id =
      case reportable
      when Post, Comment, Message, DirectMessage then reportable.user_id
      when User                                  then reportable.id
      end
    return "" if author_id == Current.session.user_id

    classes ||= "inline-flex items-center gap-1 min-h-11 text-caption text-on-surface-variant hover:text-error"
    link_to new_report_path(reportable_type: reportable.class.name, reportable_id: reportable.id),
            class: classes,
            data: { turbo_frame: "_top" } do
      tag.span("flag", class: "material-symbols-outlined", style: "font-size:14px") +
        " " + label
    end
  end
end
