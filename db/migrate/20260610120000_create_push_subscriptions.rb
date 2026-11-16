class CreatePushSubscriptions < ActiveRecord::Migration[8.1]
  def change
    # Suscripciones web push por dispositivo/navegador del usuario.
    create_table :push_subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.text   :endpoint, null: false
      t.string :p256dh,   null: false
      t.string :auth,     null: false

      t.timestamps
    end
    add_index :push_subscriptions, :endpoint, unique: true
  end
end
