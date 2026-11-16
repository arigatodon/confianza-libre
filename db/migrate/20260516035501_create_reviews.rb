class CreateReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :reviews do |t|
      t.references :reviewer, null: false, foreign_key: { to_table: :users }
      t.references :reviewed_user, null: false, foreign_key: { to_table: :users }
      t.references :post, null: false, foreign_key: true
      t.integer :score, null: false
      t.text :comment
      t.integer :category_weight, default: 1, null: false

      t.timestamps
    end
    add_index :reviews, [ :reviewer_id, :post_id ], unique: true
  end
end
