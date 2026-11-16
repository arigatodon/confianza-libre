class CrearDifusionSocial < ActiveRecord::Migration[8.1]
  def change
    # Consentimiento explícito del autor para republicar su post en las
    # redes sociales de Confianza (Telegram, Bluesky, Instagram…).
    add_column :posts, :difundir, :boolean, default: false, null: false

    create_table :social_broadcasts do |t|
      t.references :post, null: false, foreign_key: true
      t.string  :network,     null: false  # "telegram", "bluesky", "instagram"…
      t.string  :status,      null: false, default: "pendiente" # pendiente|enviado|error
      t.string  :external_id              # id del post en la red destino
      t.string  :error_message
      t.datetime :sent_at

      t.timestamps
    end

    # Un envío por red por post: la difusión es idempotente.
    add_index :social_broadcasts, [ :post_id, :network ], unique: true
  end
end
