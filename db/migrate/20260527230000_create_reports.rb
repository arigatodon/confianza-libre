class CreateReports < ActiveRecord::Migration[8.1]
  def change
    create_table :reports do |t|
      t.references :reporter, null: false, foreign_key: { to_table: :users }
      t.references :reportable, polymorphic: true, null: false
      t.integer    :reason, default: 0, null: false   # spam / abuse / harmful / offtopic / other
      t.text       :body
      t.integer    :status, default: 0, null: false   # open / hidden / warned / suspended / dismissed
      t.references :resolved_by, foreign_key: { to_table: :users }
      t.datetime   :resolved_at
      t.text       :resolution_note
      t.integer    :reward_credits, default: 0, null: false  # snapshot del reward pagado al moderador
      t.references :territory, foreign_key: true              # territorio del contenido reportado (snapshot)
      t.timestamps
    end

    add_index :reports, [ :reportable_type, :reportable_id, :status ]
    add_index :reports, :status

    # Soft-hide por moderación. Los scopes :visible filtran por estos.
    add_column :posts,    :hidden_at, :datetime
    add_column :comments, :hidden_at, :datetime
    add_column :messages, :hidden_at, :datetime
    add_index  :posts,    :hidden_at
    add_index  :comments, :hidden_at
    add_index  :messages, :hidden_at
  end
end
