class CreateAnnouncements < ActiveRecord::Migration[8.1]
  def change
    # Quién puede publicar novedades oficiales (y futuras tareas de administración).
    add_column :users, :admin, :boolean, default: false, null: false

    create_table :announcements do |t|
      t.string  :title, null: false
      t.string  :slug,  null: false
      t.text    :body,  null: false
      t.integer :kind,  null: false, default: 0
      # published_at nil = borrador. Programable a futuro.
      t.datetime :published_at
      t.references :user, null: false, foreign_key: true
      t.integer :supports_count, null: false, default: 0

      t.timestamps
    end
    add_index :announcements, :slug, unique: true
    add_index :announcements, :published_at

    # Apoyos: señal liviana de la comunidad sobre cada novedad/consulta.
    create_table :announcement_supports do |t|
      t.references :announcement, null: false, foreign_key: true
      t.references :user,         null: false, foreign_key: true

      t.timestamps
    end
    add_index :announcement_supports, [ :announcement_id, :user_id ], unique: true
  end
end
