class AddTerritoryAndCategoryToTransactions < ActiveRecord::Migration[8.1]
  def change
    # Snapshot del territorio al que fue el impuesto (auditable).
    add_reference :transactions, :territory, foreign_key: true, null: true
    # Snapshot de la categoría (para reconstruir el multiplicador aplicado).
    add_reference :transactions, :category,  foreign_key: true, null: true
  end
end
