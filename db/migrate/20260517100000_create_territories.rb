class CreateTerritories < ActiveRecord::Migration[8.1]
  def change
    create_table :territories do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :country_code, null: false, limit: 2
      t.string :admin1   # depto / provincia / estado
      t.string :admin2   # municipio / ciudad
      t.float  :latitude    # centroide (para mostrar en mapa)
      t.float  :longitude
      t.string :source, null: false, default: "admin"  # admin | custom | system

      t.timestamps
    end

    add_index :territories, :slug, unique: true
    add_index :territories, [ :country_code, :admin1, :admin2 ]
  end
end
