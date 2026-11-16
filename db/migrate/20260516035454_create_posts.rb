class CreatePosts < ActiveRecord::Migration[8.1]
  def change
    create_table :posts do |t|
      t.references :user, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.string :title, null: false
      t.string :slug
      t.text :description
      t.float :latitude
      t.float :longitude
      t.integer :status, default: 0, null: false
      t.string :kind, null: false
      t.integer :visibility_radius, default: 5000, null: false

      t.timestamps
    end
    add_index :posts, :slug, unique: true
    add_index :posts, [ :latitude, :longitude ]
    add_index :posts, :status
    add_index :posts, :kind
  end
end
