class LedgerEntry < ApplicationRecord
  DIRECTIONS = %w[debit credit].freeze

  belongs_to :credit_transaction, inverse_of: :ledger_entries
  belongs_to :account

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :direction, presence: true, inclusion: { in: DIRECTIONS }

  # Realtime: cada entrada del ledger refresca la wallet/territorio del owner
  # de la cuenta. Cada subscriber dispara su propio GET y morphea.
  # Las cuentas globales (burn/system) no tienen owner — no broadcastean.
  after_create_commit :broadcast_balance_refresh

  private

  def broadcast_balance_refresh
    if account.user_id
      Turbo::StreamsChannel.broadcast_refresh_later_to(account.user, :wallet)
    elsif account.territory_id
      Turbo::StreamsChannel.broadcast_refresh_later_to(account.territory, :wallet)
    end
  end
end
