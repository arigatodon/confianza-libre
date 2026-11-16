class AddPublishableToCategories < ActiveRecord::Migration[8.1]
  # Discrimina categorías "elegibles al publicar" de las internas (ej. Cliente).
  # No publishable: no aparece en el selector del post pero sí existe para
  # taggear reviews que no corresponden a un servicio concreto.
  def change
    add_column :categories, :publishable, :boolean, default: true, null: false
  end
end
