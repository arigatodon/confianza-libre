class AddMaxCreditMultiplierToCategories < ActiveRecord::Migration[8.1]
  def change
    add_column :categories, :max_credit_multiplier, :decimal,
               precision: 4, scale: 2, default: 1.00, null: false
  end
end
