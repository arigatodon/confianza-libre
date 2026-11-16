class AddCategoryToReviews < ActiveRecord::Migration[8.1]
  # Cada review se cuelga de una Category — antes se infería del post,
  # pero eso es incorrecto cuando el reviewer es el dueño del post: el
  # reviewer no ofreció ese servicio, lo recibió. Esas reviews deberían
  # taggearse a una categoría "Cliente" (no publishable) para acumular
  # reputación-como-cliente sin contaminar la de proveedor.
  def up
    add_reference :reviews, :category, foreign_key: true

    # Asegurar que existe la categoría "Cliente" antes del backfill.
    say_with_time "Asegurando categoría Cliente" do
      execute <<~SQL.squish
        INSERT INTO categories (name, trust_weight, allows_credit, max_credit_multiplier, publishable, created_at, updated_at, slug)
        SELECT 'Cliente', 2, false, 1.0, false, NOW(), NOW(), 'cliente'
        WHERE NOT EXISTS (SELECT 1 FROM categories WHERE name = 'Cliente')
      SQL
    end

    say_with_time "Backfill reviews → category según rol" do
      # Si reviewer == post.user → review como evaluación de cliente.
      execute <<~SQL.squish
        UPDATE reviews
        SET category_id = (SELECT id FROM categories WHERE name = 'Cliente' LIMIT 1)
        WHERE reviewer_id = (SELECT user_id FROM posts WHERE posts.id = reviews.post_id)
      SQL
      # El resto (sender → receiver) hereda la categoría del post.
      execute <<~SQL.squish
        UPDATE reviews
        SET category_id = (SELECT category_id FROM posts WHERE posts.id = reviews.post_id)
        WHERE category_id IS NULL
      SQL
    end

    change_column_null :reviews, :category_id, false
  end

  def down
    remove_reference :reviews, :category, foreign_key: true
  end
end
