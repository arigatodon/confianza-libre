class CreateDisputes < ActiveRecord::Migration[8.1]
  def change
    create_table :disputes do |t|
      t.references :interaction, null: false, foreign_key: true, index: { unique: true }
      t.references :opener,      null: false, foreign_key: { to_table: :users }
      t.text :argument, null: false
      t.text :response
      t.datetime :responded_at
      t.integer :status, default: 0, null: false
      t.integer :verdict
      t.integer :resolution_amount
      t.text :resolution_note
      t.references :resolved_by, foreign_key: { to_table: :users }
      t.datetime :resolved_at

      t.timestamps
    end
    add_index :disputes, :status
  end
end
