class RebuildProposals < ActiveRecord::Migration[8.1]
  # La tabla `proposals` original venía del bootstrap inicial con un schema
  # pensado para "propuestas genéricas". El sistema económico v0.2 requiere
  # propuestas atadas a un Territory que gastan créditos de su fondo
  # comunitario a favor de un beneficiario concreto. Como no hay registros,
  # la reescribimos limpiamente.
  def up
    drop_table :proposal_votes, if_exists: true
    drop_table :proposals,      if_exists: true

    create_table :proposals do |t|
      t.references :territory,             null: false, foreign_key: true
      t.references :proposer,              null: false, foreign_key: { to_table: :users }
      t.references :beneficiary,           null: false, foreign_key: { to_table: :users }
      t.references :execution_transaction,              foreign_key: { to_table: :transactions }
      t.string     :title,                 null: false
      t.text       :body,                  null: false
      t.integer    :amount,                null: false, default: 0
      t.integer    :status,                null: false, default: 0
      t.datetime   :voting_closes_at,      null: false
      t.timestamps
    end

    create_table :proposal_votes do |t|
      t.references :proposal, null: false, foreign_key: true
      t.references :user,     null: false, foreign_key: true
      t.integer    :position, null: false
      t.timestamps
    end

    add_index :proposals,      [ :territory_id, :status ]
    add_index :proposal_votes, [ :proposal_id, :user_id ], unique: true
  end

  def down
    drop_table :proposal_votes
    drop_table :proposals

    # Restauramos el schema original para no romper rollback completo.
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
