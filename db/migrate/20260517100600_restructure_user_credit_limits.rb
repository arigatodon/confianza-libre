class RestructureUserCreditLimits < ActiveRecord::Migration[8.1]
  # La capacidad crediticia pertenece al usuario, no a su cuenta.
  # accounts.credit_limit deja de ser fuente de verdad.
  #
  # Defaults = Nivel 1 (ver ECONOMIA.md § 4.1):
  #   credit_floor   = 100
  #   credit_ceiling = 1.000
  #   tx_cap         = 50
  def change
    add_column :users, :level,          :integer, null: false, default: 1
    add_column :users, :credit_floor,   :integer, null: false, default: 100
    add_column :users, :credit_ceiling, :integer, null: false, default: 1_000
    add_column :users, :tx_cap,         :integer, null: false, default: 50

    add_index :users, :level

    # Reversible: el `default` y `null` permiten al esquema reconstruir la columna
    # si se hace rollback de esta migración.
    remove_column :accounts, :credit_limit, :integer, default: 100, null: false
  end
end
