class CreateTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :transactions do |t|
      t.references :interaction, null: false, foreign_key: true
      t.string :uuid, null: false
      t.integer :status, default: 0, null: false
      t.integer :total_amount, null: false
      t.integer :burn_amount, default: 0, null: false
      t.integer :community_amount, default: 0, null: false

      t.timestamps
    end
    add_index :transactions, :uuid, unique: true
  end
end
