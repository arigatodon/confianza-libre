class AddModeratorSinceToUsers < ActiveRecord::Migration[8.1]
  # Fase 1.3 — Desacoplar el rol de moderador del nivel económico.
  # Antes: moderator? = level >= 3 (acumular crédito daba poder de policía).
  # Ahora: un flag otorgable/revocable por gobernanza.
  def up
    add_column :users, :moderator_since, :datetime

    # Bootstrap: los moderadores actuales (L3+ o admin) conservan el rol.
    execute "UPDATE users SET moderator_since = NOW() WHERE level >= 3 OR admin = true;"
  end

  def down
    remove_column :users, :moderator_since
  end
end
