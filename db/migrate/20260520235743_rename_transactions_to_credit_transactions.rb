class RenameTransactionsToCreditTransactions < ActiveRecord::Migration[8.1]
  # `Transaction` choca con `ActiveRecord::Base.transaction` y obligaba al
  # work-around `inheritance_column = :_type_disabled` + association
  # `transaction_record`. Renombrar el modelo y todas las columnas saca esa
  # fricción de raíz. Ver pendiente.md (bloque A).
  #
  # Rails 8 auto-renombra los índices tanto en `rename_column` como en
  # `rename_table`, así que no hace falta tocarlos a mano.

  def up
    remove_foreign_key :ledger_entries, :transactions
    rename_column      :ledger_entries, :transaction_id, :credit_transaction_id

    remove_foreign_key :proposals, column: :execution_transaction_id
    rename_column      :proposals, :execution_transaction_id, :execution_credit_transaction_id

    rename_table :transactions, :credit_transactions

    # `rename_table` auto-renombra los índices estándar (`index_<table>_on_<col>`),
    # pero el índice compuesto del polimórfico `source` lleva un nombre custom.
    rename_index :credit_transactions,
                 "index_transactions_on_source",
                 "index_credit_transactions_on_source"

    add_foreign_key :ledger_entries, :credit_transactions
    add_foreign_key :proposals, :credit_transactions, column: :execution_credit_transaction_id
  end

  def down
    remove_foreign_key :proposals, column: :execution_credit_transaction_id
    remove_foreign_key :ledger_entries, :credit_transactions

    rename_index :credit_transactions,
                 "index_credit_transactions_on_source",
                 "index_transactions_on_source"

    rename_table :credit_transactions, :transactions

    rename_column :proposals, :execution_credit_transaction_id, :execution_transaction_id
    add_foreign_key :proposals, :transactions, column: :execution_transaction_id

    rename_column :ledger_entries, :credit_transaction_id, :transaction_id
    add_foreign_key :ledger_entries, :transactions
  end
end
