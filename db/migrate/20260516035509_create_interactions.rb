class CreateInteractions < ActiveRecord::Migration[8.1]
  def change
    create_table :interactions do |t|
      t.references :post, null: false, foreign_key: true
      t.references :sender, null: false, foreign_key: { to_table: :users }
      t.references :receiver, null: false, foreign_key: { to_table: :users }
      t.integer :status, default: 0, null: false
      t.integer :agreed_credits, default: 0, null: false

      t.timestamps
    end
    add_index :interactions, :status
  end
end
