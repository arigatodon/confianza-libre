class CreateIdentityVerifications < ActiveRecord::Migration[8.1]
  # Fase 1.2 — Verificación de identidad (desbloquea L5). El usuario sube 1–2
  # imágenes de documento (ActiveStorage) y un moderador L3+ aprueba o rechaza.
  # Las imágenes se purgan a los 30 días de resolverse (no somos custodios).
  def change
    create_table :identity_verifications do |t|
      t.references :user, null: false, foreign_key: true
      t.integer    :status, null: false, default: 0
      t.text       :note
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.datetime   :reviewed_at
      t.timestamps
    end

    add_index :identity_verifications, [ :user_id, :status ]
  end
end
