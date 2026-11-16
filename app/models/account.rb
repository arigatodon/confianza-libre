class Account < ApplicationRecord
  ACCOUNT_TYPES = %w[user community burn system].freeze

  belongs_to :user,      optional: true
  belongs_to :territory, optional: true, inverse_of: :community_account

  has_many :ledger_entries, dependent: :restrict_with_error

  validates :account_type, presence: true, inclusion: { in: ACCOUNT_TYPES }
  validates :cached_balance, numericality: true

  validate :ownership_matches_type

  # available_balance es relevante para account_type = 'user'. Para las demás
  # cuentas, cached_balance ya es el "disponible". El piso (credit_floor) vive
  # en el User, no en la cuenta.
  def available_balance
    return cached_balance unless account_type == "user"
    cached_balance + (user&.credit_floor || 0)
  end

  private

  def ownership_matches_type
    case account_type
    when "user"
      errors.add(:user_id, "es requerido para cuentas de usuario") if user_id.blank?
      errors.add(:territory_id, "debe ser nulo para cuentas de usuario") if territory_id.present?
    when "community"
      errors.add(:territory_id, "es requerido para cuentas de territorio") if territory_id.blank?
      errors.add(:user_id, "debe ser nulo para cuentas de territorio") if user_id.present?
    when "burn", "system"
      errors.add(:user_id, "debe ser nulo para cuentas globales") if user_id.present?
      errors.add(:territory_id, "debe ser nulo para cuentas globales") if territory_id.present?
    end
  end
end
