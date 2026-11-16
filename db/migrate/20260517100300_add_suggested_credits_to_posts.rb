class AddSuggestedCreditsToPosts < ActiveRecord::Migration[8.1]
  def change
    # Valor de referencia que el creador propone (opcional).
    add_column :posts, :suggested_credits, :integer
  end
end
