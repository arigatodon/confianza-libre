class AddVitrinaToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :whatsapp, :string
    add_column :users, :horario, :string
    add_column :users, :vitrina_plantilla, :string
    add_column :users, :accent_color, :string
    add_column :users, :vitrina_links, :jsonb, default: {}, null: false
  end
end
