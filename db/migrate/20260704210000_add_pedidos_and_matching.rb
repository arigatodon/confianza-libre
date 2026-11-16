class AddPedidosAndMatching < ActiveRecord::Migration[8.1]
  # Fase 2.2 — Pedidos + matching automático.
  # - `posts.pedido`: la otra mitad del mercado. false = ofrezco, true = busco.
  # - Preferencias de aviso por usuario: on/off, radio y categorías de interés.
  # - Parámetro gobernable `match_daily_cap`: tope de avisos de match por día.
  def up
    add_column :posts, :pedido, :boolean, default: false, null: false
    add_index  :posts, :pedido, where: "pedido"

    add_column :users, :match_notifications, :boolean, default: true, null: false
    add_column :users, :match_radius_km, :integer, default: 25, null: false
    # Categorías para las que quiero avisos; vacío = las de mis publicaciones.
    add_column :users, :match_category_ids, :integer, array: true, default: [], null: false

    # Parámetro económico gobernable (idempotente: no pisar si ya existe).
    execute <<~SQL
      INSERT INTO economic_parameters (key, value, description, created_at, updated_at)
      VALUES ('match_daily_cap', '5',
              'Máximo de avisos de match (pedidos/ofertas compatibles) por usuario por día.',
              NOW(), NOW())
      ON CONFLICT (key) DO NOTHING;
    SQL
  end

  def down
    execute "DELETE FROM economic_parameters WHERE key = 'match_daily_cap';"
    remove_column :users, :match_category_ids
    remove_column :users, :match_radius_km
    remove_column :users, :match_notifications
    remove_index  :posts, :pedido
    remove_column :posts, :pedido
  end
end
