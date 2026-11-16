xml.instruct! :xml, version: "1.0"
xml.urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9" do
  # Páginas estáticas
  [
    [ root_url,         "daily",   1.0 ],
    [ explore_url,      "hourly",  0.9 ],
    [ posts_url,        "hourly",  0.9 ],
    [ how_it_works_url,  "monthly", 0.6 ],
    [ economics_url,     "monthly", 0.5 ],
    [ manifesto_url,     "monthly", 0.7 ],
    [ announcements_url, "daily",   0.8 ],
    [ people_url,        "weekly",  0.6 ],
    [ territories_url,   "weekly",  0.6 ]
  ].each do |loc, changefreq, priority|
    xml.url do
      xml.loc loc
      xml.changefreq changefreq
      xml.priority priority
    end
  end

  @posts.find_each do |post|
    xml.url do
      xml.loc post_url(post)
      xml.lastmod post.updated_at.iso8601
      xml.changefreq "weekly"
      xml.priority 0.7
    end
  end

  @announcements.find_each do |announcement|
    xml.url do
      xml.loc announcement_url(announcement)
      xml.lastmod announcement.updated_at.iso8601
      xml.changefreq "monthly"
      xml.priority 0.7
    end
  end

  @territories.find_each do |territory|
    xml.url do
      xml.loc territory_url(territory)
      xml.lastmod territory.updated_at.iso8601
      xml.changefreq "weekly"
      xml.priority 0.5
    end
  end

  @users.find_each do |user|
    xml.url do
      xml.loc profile_url(user.username)
      xml.lastmod user.updated_at.iso8601
      xml.changefreq "weekly"
      xml.priority 0.6
    end
  end
end
