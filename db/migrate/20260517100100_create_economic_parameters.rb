class CreateEconomicParameters < ActiveRecord::Migration[8.1]
  def change
    create_table :economic_parameters do |t|
      t.string :key,   null: false
      t.string :value, null: false
      t.text   :description
      t.bigint :updated_by_user_id

      t.timestamps
    end

    add_index :economic_parameters, :key, unique: true
  end
end
