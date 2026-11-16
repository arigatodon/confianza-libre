class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.integer :trust_weight, default: 1, null: false
      t.boolean :allows_credit, default: false, null: false

      t.timestamps
    end
    add_index :categories, :slug, unique: true
    add_index :categories, :name, unique: true
  end
end
