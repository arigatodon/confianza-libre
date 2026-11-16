class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    # Mensajes directos entre dos usuarios, fuera de una interacción.
    # El par se guarda normalizado (participant_a_id < participant_b_id)
    # para que entre dos personas exista una sola conversación.
    create_table :conversations do |t|
      t.references :participant_a, null: false, foreign_key: { to_table: :users }
      t.references :participant_b, null: false, foreign_key: { to_table: :users }
      t.datetime :last_message_at

      t.timestamps
    end
    add_index :conversations, [ :participant_a_id, :participant_b_id ], unique: true

    create_table :direct_messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :user,         null: false, foreign_key: true
      t.text :body, null: false
      t.datetime :hidden_at

      t.timestamps
    end
  end
end
