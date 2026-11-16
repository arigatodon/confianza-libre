class LedgerController < ApplicationController
  allow_unauthenticated_access only: :audit

  # Endpoint público de auditoría. La integridad del sistema depende de la
  # partida doble — si en algún momento Σ debits ≠ Σ credits, la red entera
  # se rompe. Exponer este endpoint:
  #   · obliga a que el equipo lo mantenga sano.
  #   · permite que cualquiera lo verifique sin acceso a la DB.
  def audit
    @data = Rails.cache.fetch("ledger_audit", expires_in: 5.minutes) { compute_audit }
  end

  private

  def compute_audit
    by_type = Account.group(:account_type).sum(:cached_balance)

    debits_total  = LedgerEntry.where(direction: "debit").sum(:amount)
    credits_total = LedgerEntry.where(direction: "credit").sum(:amount)

    completed = CreditTransaction.where(status: :completed)

    unbalanced = LedgerEntry
                   .group(:credit_transaction_id)
                   .group(:direction)
                   .sum(:amount)
                   .each_with_object({}) { |((tx_id, dir), amt), h| h[tx_id] ||= {}; h[tx_id][dir] = amt }
                   .reject { |_, sides| sides["debit"].to_i == sides["credit"].to_i }
                   .keys

    {
      generated_at: Time.current,
      balances_by_type: {
        user:      by_type["user"].to_i,
        community: by_type["community"].to_i,
        burn:      by_type["burn"].to_i,
        system:    by_type["system"].to_i
      },
      sum_global:       Account.sum(:cached_balance).to_i,
      ledger_debits:    debits_total.to_i,
      ledger_credits:   credits_total.to_i,
      ledger_delta:     (credits_total - debits_total).to_i,
      accounts_total:   Account.count,
      users_with_account: Account.where(account_type: "user").count,
      territories_with_fund: Account.where(account_type: "community").count,
      transactions_total:     CreditTransaction.count,
      transactions_completed: completed.count,
      total_volume_completed: completed.sum(:total_amount).to_i,
      total_burned:           completed.sum(:burn_amount).to_i,
      total_territorial:      completed.sum(:community_amount).to_i,
      unbalanced_transaction_ids: unbalanced
    }
  end
end
