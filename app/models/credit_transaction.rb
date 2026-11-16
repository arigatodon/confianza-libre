class CreditTransaction < ApplicationRecord
  STATUSES = { pending: 0, completed: 1, reversed: 2, failed: 3 }.freeze

  enum :status, STATUSES

  belongs_to :interaction, optional: true
  belongs_to :source,      polymorphic: true, optional: true
  belongs_to :territory,   optional: true
  belongs_to :category,    optional: true
  has_many :ledger_entries, dependent: :restrict_with_error, inverse_of: :credit_transaction

  before_validation :assign_uuid, on: :create

  validates :uuid, presence: true, uniqueness: true
  validates :total_amount, :burn_amount, :community_amount,
            presence: true,
            numericality: { greater_than_or_equal_to: 0 }

  validate :ledger_must_balance, on: :update, if: -> { completed? }

  private

  def assign_uuid
    self.uuid ||= SecureRandom.uuid
  end

  def ledger_must_balance
    debits  = ledger_entries.where(direction: "debit").sum(:amount)
    credits = ledger_entries.where(direction: "credit").sum(:amount)
    return if debits == credits

    errors.add(:base, "ledger desbalanceado (debits=#{debits}, credits=#{credits})")
  end
end
