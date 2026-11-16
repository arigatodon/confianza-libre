class AddKindAndPayloadToProposals < ActiveRecord::Migration[8.1]
  def change
    # kind 0 = fund_transfer (las propuestas existentes son todas de fondo).
    add_column :proposals, :kind, :integer, default: 0, null: false
    # payload guarda los datos específicos del kind (nombre de categoría,
    # parámetro y valor propuesto) sin sumar columnas por cada tipo nuevo.
    add_column :proposals, :payload, :jsonb, default: {}, null: false

    # beneficiary/amount sólo aplican a fund_transfer.
    change_column_null :proposals, :beneficiary_id, true

    add_index :proposals, [ :territory_id, :kind ]
  end
end
