class AddInteractionToReviews < ActiveRecord::Migration[8.1]
  # Las reviews pasan a colgar de una Interaction concreta, no sólo del Post.
  # Eso habilita doble review (sender ↔ receiver) sobre la misma interacción
  # y mantiene la trazabilidad económica: una review = un encuentro real.
  def up
    add_reference :reviews, :interaction, foreign_key: true

    say_with_time "Backfill reviews → interactions" do
      # Match: misma publicación, interaction completada (status 3) y el par
      # reviewer/reviewed_user calza con sender/receiver en cualquier orden.
      execute <<~SQL.squish
        UPDATE reviews r
        SET    interaction_id = i.id
        FROM   interactions i
        WHERE  r.interaction_id IS NULL
          AND  i.post_id = r.post_id
          AND  i.status  = 3
          AND  ((i.sender_id   = r.reviewer_id      AND i.receiver_id = r.reviewed_user_id)
             OR (i.receiver_id = r.reviewer_id      AND i.sender_id   = r.reviewed_user_id))
      SQL
    end

    huerfanas = execute("SELECT COUNT(*) AS c FROM reviews WHERE interaction_id IS NULL").first["c"].to_i
    if huerfanas.positive?
      say "Eliminando #{huerfanas} review(s) sin Interaction asociada"
      execute "DELETE FROM reviews WHERE interaction_id IS NULL"
    end

    remove_index :reviews, name: :index_reviews_on_reviewer_id_and_post_id
    add_index :reviews, [ :reviewer_id, :interaction_id ], unique: true

    change_column_null :reviews, :interaction_id, false
  end

  def down
    change_column_null :reviews, :interaction_id, true
    remove_index :reviews, [ :reviewer_id, :interaction_id ]
    add_index :reviews, [ :reviewer_id, :post_id ], unique: true
    remove_reference :reviews, :interaction, foreign_key: true
  end
end
