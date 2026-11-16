class ChangeTrustScoreToDecimal < ActiveRecord::Migration[8.1]
  # trust_score es un promedio ponderado (0.00 — 5.00), no un contador entero.
  # Default 3.0 = neutral hasta que el usuario acumule ≥ 3 reviewers distintos
  # (ver ECONOMIA.md § 6).
  def up
    change_column :users, :trust_score, :decimal, precision: 4, scale: 2, default: 3.0, null: false
    execute "UPDATE users SET trust_score = 3.0 WHERE trust_score = 0"
  end

  def down
    execute "UPDATE users SET trust_score = 0 WHERE trust_score = 3.0"
    change_column :users, :trust_score, :integer, default: 0, null: false
  end
end
