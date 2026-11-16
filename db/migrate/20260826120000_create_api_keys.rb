# Claves de API para publicar en Confianza desde un sitio propio (API pública).
# Se guarda solo el hash SHA-256 del token: el texto plano se muestra una vez.
class CreateApiKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :api_keys do |t|
      t.references :user, null: false, foreign_key: true
      t.string  :name,         null: false, default: "Mi web"
      t.string  :token_digest, null: false
      t.string  :prefix,       null: false   # primeros caracteres, para reconocerla en Ajustes
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :api_keys, :token_digest, unique: true
  end
end
