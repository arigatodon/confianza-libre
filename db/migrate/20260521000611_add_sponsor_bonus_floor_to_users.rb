class AddSponsorBonusFloorToUsers < ActiveRecord::Migration[8.1]
  # Padrinazgo: el ahijado arranca con un colchón extra sobre el credit_floor
  # del nivel 1. La columna es aditiva — el CreditLimitCalculator suma este
  # bonus al floor base de la tabla de niveles, así no choca con la recalc
  # automática del job de nivel.
  def change
    add_column :users, :sponsor_bonus_floor, :integer, default: 0, null: false
  end
end
