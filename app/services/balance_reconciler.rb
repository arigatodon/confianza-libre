class BalanceReconciler
  # Recompone el cached_balance de una Account a partir de sus ledger_entries.
  # El ledger es la fuente de verdad — cached_balance es sólo una denormalización
  # que puede driftear (ej.: balances modificados a mano en consola, fallas
  # parciales antes de envolver todo en una DB transaction, etc.).
  #
  #   expected = Σ credits − Σ debits

  def self.call(account)
    debits  = account.ledger_entries.where(direction: "debit").sum(:amount)
    credits = account.ledger_entries.where(direction: "credit").sum(:amount)
    credits - debits
  end
end
