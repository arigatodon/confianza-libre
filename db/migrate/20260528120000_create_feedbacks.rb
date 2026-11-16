class CreateFeedbacks < ActiveRecord::Migration[8.1]
  def change
    create_table :feedbacks do |t|
      t.references :user, foreign_key: true, null: true
      t.integer :kind,   null: false, default: 0
      t.text    :body,   null: false
      t.integer :status, null: false, default: 0
      t.string  :url
      t.string  :user_agent
      t.timestamps
    end
    add_index :feedbacks, :status
    add_index :feedbacks, :kind
  end
end
