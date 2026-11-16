class CreateEndorsements < ActiveRecord::Migration[8.1]
  def change
    # Aval comunitario: vecinos de nivel alto dan fe de que una persona es
    # real y de fiar. N avales suben la verificación (en vez de SMS pagos).
    create_table :endorsements do |t|
      t.references :endorser, null: false, foreign_key: { to_table: :users }
      t.references :endorsed, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
    add_index :endorsements, [ :endorser_id, :endorsed_id ], unique: true
  end
end
