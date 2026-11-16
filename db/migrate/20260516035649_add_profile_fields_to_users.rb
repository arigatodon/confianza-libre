class AddProfileFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :username, :string
    add_index :users, :username, unique: true
    add_column :users, :slug, :string
    add_index :users, :slug, unique: true
    add_column :users, :bio, :text
    add_column :users, :latitude, :float
    add_column :users, :longitude, :float
    add_column :users, :trust_score, :integer, default: 0, null: false
    add_column :users, :territory_score, :integer, default: 0, null: false
    add_column :users, :verification_level, :integer, default: 0, null: false
    add_column :users, :status, :integer, default: 0, null: false
    add_reference :users, :sponsor, null: true, foreign_key: { to_table: :users }
    add_index :users, [ :latitude, :longitude ]
  end
end
