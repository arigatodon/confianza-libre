class MakeTransactionSourcePolymorphic < ActiveRecord::Migration[8.1]
  # Hasta ahora una Transaction siempre venía de una Interaction. Cuando
  # entran las Proposals (gasto del fondo territorial por votación), el
  # "origen contable" deja de ser únicamente una interacción → polimórfico.
  def up
    add_reference :transactions, :source, polymorphic: true, index: true

    say_with_time "Backfill source desde interaction_id" do
      execute <<~SQL.squish
        UPDATE transactions
        SET    source_type = 'Interaction',
               source_id   = interaction_id
        WHERE  interaction_id IS NOT NULL
      SQL
    end

    change_column_null :transactions, :interaction_id, true
  end

  def down
    execute "DELETE FROM transactions WHERE interaction_id IS NULL"
    change_column_null :transactions, :interaction_id, false
    remove_reference  :transactions, :source, polymorphic: true
  end
end
