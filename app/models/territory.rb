class Territory < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged

  SOURCES = %w[admin custom system].freeze

  has_one :community_account,
          -> { where(account_type: "community") },
          class_name: "Account",
          inverse_of: :territory

  has_many :proposals, dependent: :destroy

  validates :name,         presence: true
  validates :slug,         presence: true, uniqueness: true
  validates :country_code, presence: true, length: { is: 2 }
  validates :source,       inclusion: { in: SOURCES }

  def to_s
    name
  end

  # Miembros con actividad económica real en el territorio (participantes
  # distintos de transacciones completadas). Es la vara de los escalones de
  # gobernanza: a más miembros activos, más poder de decisión local.
  def active_members_count
    CreditTransaction.where(territory: self, status: :completed)
                     .joins(:interaction)
                     .pluck("interactions.sender_id", "interactions.receiver_id")
                     .flatten.uniq.size
  end

  # Garantiza que exista la cuenta community asociada (se llama desde TerritoryResolver).
  def ensure_community_account!
    community_account || Account.create!(account_type: "community", territory: self, cached_balance: 0)
  end
end
