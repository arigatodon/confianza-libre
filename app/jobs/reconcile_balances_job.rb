# Corre semanal por Solid Queue (config/recurring.yml). Compara el
# cached_balance de cada cuenta contra el ledger (la fuente de verdad),
# corrige el drift y avisa por email: un drift significa que algo escribió
# balances fuera de una transacción sana — hay que mirarlo, no solo parcharlo.
class ReconcileBalancesJob < ApplicationJob
  queue_as :default

  def perform
    drifted = []

    Account.find_each do |account|
      expected = BalanceReconciler.call(account)
      next if account.cached_balance == expected

      drifted << { account_id: account.id,
                   account_type: account.account_type,
                   owner: owner_label(account),
                   cached: account.cached_balance,
                   expected: expected }
      account.update_column(:cached_balance, expected)
    end

    total = Account.sum(:cached_balance)
    if drifted.any? || total != 0
      ErrorMailer.ledger_drift(drifted: drifted, total_after: total).deliver_later
    end

    Rails.logger.info("[ReconcileBalancesJob] drift en #{drifted.size} cuenta(s); Σ=#{total}")
    drifted.size
  end

  private

  def owner_label(account)
    case account.account_type
    when "user"      then "user=#{account.user&.username || account.user_id}"
    when "community" then "territory=#{account.territory&.slug || account.territory_id}"
    else                  account.account_type
    end
  end
end
