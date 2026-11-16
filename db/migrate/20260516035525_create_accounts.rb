class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :account_type, default: "user", null: false
      t.integer :cached_balance, default: 0, null: false
      t.integer :credit_limit, default: 100, null: false

      t.timestamps
    end
    add_index :accounts, [ :user_id, :account_type ], unique: true
  end
end
