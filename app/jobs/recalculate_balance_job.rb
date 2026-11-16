class RecalculateBalanceJob < ApplicationJob
  queue_as :default

  # Reconcilia cached_balance contra el ledger. Útil para batch nocturno o
  # para reparar cuentas individuales después de mantenimientos.
  def perform(account_id)
    account = Account.find_by(id: account_id)
    return unless account

    account.update_column(:cached_balance, BalanceReconciler.call(account))
  end
end
