class Category < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged

  has_many :posts, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :trust_weight, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :max_credit_multiplier, numericality: { greater_than: 0, less_than_or_equal_to: 5 }

  scope :publishable, -> { where(publishable: true) }

  # La categoría "Cliente" es interna: no aparece en el selector del post
  # pero taggea las reviews del dueño del post hacia el sender (que actuó
  # como cliente). Singleton — siempre existe (seed la asegura).
  def self.client
    @client ||= find_by(name: "Cliente")
  end

  def to_s
    name
  end
end
