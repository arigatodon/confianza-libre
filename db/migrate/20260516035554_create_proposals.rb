class CreateProposals < ActiveRecord::Migration[8.1]
  def change
    create_table :proposals do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.string :slug
      t.text :description
      t.integer :status, default: 0, null: false
      t.integer :votes_count, default: 0, null: false

      t.timestamps
    end
    add_index :proposals, :slug, unique: true
  end
end
