# Analítica propia y sin cookies: una fila por página HTML vista. El visitante
# se identifica con un hash de IP + user agent + sal diaria, así que se puede
# contar "visitantes únicos por día" sin poder seguir a nadie entre días.
class CreatePageViews < ActiveRecord::Migration[8.1]
  def change
    create_table :page_views do |t|
      t.date    :visited_on,     null: false
      t.string  :path,           null: false
      t.string  :visitor_digest, null: false
      t.boolean :logged_in, null: false, default: false   # sin guardar quién
      t.string  :referrer_host
      t.string  :utm_source
      t.string  :utm_campaign
      t.boolean :app, null: false, default: false   # Hotwire Native (Android)
      t.datetime :created_at, null: false
    end
    add_index :page_views, [ :visited_on, :visitor_digest ]
    add_index :page_views, [ :visited_on, :path ]
  end
end
