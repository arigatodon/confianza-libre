class Conversation < ApplicationRecord
  belongs_to :participant_a, class_name: "User"
  belongs_to :participant_b, class_name: "User"
  has_many :direct_messages, dependent: :destroy

  validates :participant_a_id, uniqueness: { scope: :participant_b_id }
  validate  :participants_differ

  before_validation :normalize_order

  scope :involving,  ->(user) { where(participant_a_id: user.id).or(where(participant_b_id: user.id)) }
  scope :by_recency, -> { order(Arel.sql("COALESCE(conversations.last_message_at, conversations.created_at) DESC")) }

  # Única conversación entre dos personas, en cualquier orden.
  def self.between!(one, other)
    a, b = [ one, other ].sort_by(&:id)
    find_or_create_by!(participant_a: a, participant_b: b)
  end

  def other_party(user)
    user.id == participant_a_id ? participant_b : participant_a
  end

  def participant?(user)
    user && [ participant_a_id, participant_b_id ].include?(user.id)
  end

  def last_message
    direct_messages.visible.ordered.last
  end

  private

  def participants_differ
    errors.add(:base, "no puedes conversar contigo mismo") if participant_a_id == participant_b_id
  end

  def normalize_order
    return if participant_a_id.nil? || participant_b_id.nil?
    if participant_a_id > participant_b_id
      self.participant_a_id, self.participant_b_id = participant_b_id, participant_a_id
    end
  end
end
