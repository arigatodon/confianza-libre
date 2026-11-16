class RestructureAccountOwnership < ActiveRecord::Migration[8.1]
  # Las cuentas dejan de ser exclusivamente de usuario.
  #   - account_type = 'user'      → user_id presente,  territory_id nulo
  #   - account_type = 'community' → territory_id presente, user_id nulo
  #   - account_type = 'burn'      → globales, ambos nulos
  #   - account_type = 'system'    → globales, ambos nulos
  def change
    change_column_null :accounts, :user_id, true
    add_reference :accounts, :territory, foreign_key: true, null: true

    # El índice viejo asumía (user_id, account_type) con user_id NOT NULL.
    remove_index :accounts, name: "index_accounts_on_user_id_and_account_type"

    # 1 cuenta 'user' por user.
    add_index :accounts, :user_id,
              unique: true,
              where: "account_type = 'user' AND user_id IS NOT NULL",
              name: "idx_accounts_one_user_per_user_id"

    # 1 cuenta 'community' por territorio.
    add_index :accounts, :territory_id,
              unique: true,
              where: "account_type = 'community' AND territory_id IS NOT NULL",
              name: "idx_accounts_one_community_per_territory"

    # 1 sola cuenta 'burn' y 1 sola 'system' a nivel global.
    add_index :accounts, :account_type,
              unique: true,
              where: "account_type IN ('burn', 'system')",
              name: "idx_accounts_one_global_per_type"
  end
end
