xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0", "xmlns:atom" => "http://www.w3.org/2005/Atom" do
  xml.channel do
    xml.title       "Novedades de Confianza"
    xml.description "Bitácora abierta del desarrollo de Confianza: cambios, versiones y consultas a la comunidad."
    xml.link        announcements_url
    xml.language    "es"
    xml.tag! "atom:link", href: announcements_url(format: :rss), rel: "self", type: "application/rss+xml"

    @announcements.each do |announcement|
      xml.item do
        xml.title       announcement.title
        xml.description announcement.excerpt(500)
        xml.pubDate     announcement.published_at.rfc822
        xml.link        announcement_url(announcement)
        xml.guid        announcement_url(announcement)
      end
    end
  end
end
