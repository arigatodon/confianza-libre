class CreateSavedSearches < ActiveRecord::Migration[8.1]
  # Fase 2.3 — Alertas guardadas: una búsqueda de /explore (texto + filtros +
  # radio alrededor de un punto) que avisa cuando aparece un post que calza.
  def change
    create_table :saved_searches do |t|
      t.references :user, null: false, foreign_key: true
      t.string  :query
      t.references :category, foreign_key: true # nil = cualquier categoría
      t.string  :kind        # nil = cualquier tipo
      t.string  :market      # "ofertas" | "pedidos" | nil (todo)
      t.integer :credits_max
      t.integer :radius_km
      t.float   :latitude    # centro "por acá" al momento de guardar
      t.float   :longitude
      t.timestamps
    end
  end
end
