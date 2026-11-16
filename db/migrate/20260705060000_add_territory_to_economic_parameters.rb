class AddTerritoryToEconomicParameters < ActiveRecord::Migration[8.1]
  # Fase 3.1 — Economía territorial real (cumplir P3 del diagnóstico: hoy las
  # "reglas locales" son de hecho globales). Un parámetro puede tener un
  # override por territorio; territory_id NULL = valor global (el default de la
  # red). Lectura: override local → global → default en código.
  def up
    add_reference :economic_parameters, :territory, foreign_key: true, null: true

    # El índice único pasa a ser (key, territory_id): una fila global por key
    # (territory_id NULL) más una por territorio. NULLS NOT DISTINCT (PG15+)
    # garantiza que no haya dos globales con la misma key.
    remove_index :economic_parameters, :key
    execute <<~SQL
      CREATE UNIQUE INDEX index_economic_parameters_on_key_and_territory
        ON economic_parameters (key, territory_id) NULLS NOT DISTINCT;
    SQL
  end

  def down
    execute "DROP INDEX IF EXISTS index_economic_parameters_on_key_and_territory;"
    remove_reference :economic_parameters, :territory, foreign_key: true
    add_index :economic_parameters, :key, unique: true
  end
end
