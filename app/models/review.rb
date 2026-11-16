class Review < ApplicationRecord
  belongs_to :reviewer,      class_name: "User", inverse_of: :reviews_given
  belongs_to :reviewed_user, class_name: "User", inverse_of: :reviews_received
  belongs_to :post
  belongs_to :interaction
  belongs_to :category

  validates :score, presence: true, inclusion: { in: 1..5 }
  validates :reviewer_id, uniqueness: { scope: :interaction_id, message: "ya evaluaste esta interacción" }
  validate :reviewer_is_not_reviewed_user
  validate :reviewer_and_reviewed_match_interaction

  # La categoría de una review depende del rol del reviewer en la interaction:
  # · reviewer == post.user → evaluación AL CLIENTE → categoría "Cliente".
  # · resto → evaluación AL PROVEEDOR → categoría del post.
  # category_weight es snapshot de category.trust_weight al momento de crear.
  before_validation :assign_category_from_role, on: :create

  after_create_commit :enqueue_trust_recalc
  after_create_commit :notify_reviewed_user
  after_create_commit :broadcast_realtime_refresh

  private

  # Realtime: cualquier viewer del post o del perfil del reviewed_user ve
  # la nueva review sin recargar. Cada subscriber dispara su propio GET y
  # morph del DOM contra la versión fresca renderizada para su perspectiva.
  def broadcast_realtime_refresh
    broadcast_refresh_later_to(post)
    broadcast_refresh_later_to(reviewed_user)
  end

  def assign_category_from_role
    return unless post
    self.category = if reviewer_id == post.user_id
                      Category.client
                    else
                      post.category
                    end
    self.category_weight = category&.trust_weight || 1
  end

  def enqueue_trust_recalc
    RecalculateUserTrustJob.perform_later(reviewed_user_id)
  end

  def notify_reviewed_user
    NotificationCreator.call(
      recipient:  reviewed_user,
      actor:      reviewer,
      notifiable: self,
      kind:       "review_received",
      body:       "@#{reviewer.username} te evaluó con #{score}/5 en '#{post.title}'"
    )
  end

  def reviewer_is_not_reviewed_user
    return unless reviewer_id == reviewed_user_id

    errors.add(:reviewed_user_id, "no puedes evaluarte a ti mismo")
  end

  def reviewer_and_reviewed_match_interaction
    return unless interaction

    pair = [ interaction.sender_id, interaction.receiver_id ]
    return if pair.include?(reviewer_id) && pair.include?(reviewed_user_id) &&
              reviewer_id != reviewed_user_id

    errors.add(:reviewer_id, "no coincide con las partes de la interacción")
  end
end
