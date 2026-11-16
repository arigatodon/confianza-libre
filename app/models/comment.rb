class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :post
  has_many :reports, as: :reportable, dependent: :destroy

  validates :body, presence: true, length: { maximum: 1000 }

  scope :recent,  -> { order(created_at: :desc) }
  scope :visible, -> { where(hidden_at: nil) }

  def hidden_by_moderation?
    hidden_at.present?
  end

  # Realtime: nuevos comments aparecen en vivo para cualquiera viendo el
  # post. En destroy, el elemento se quita por dom_id.
  broadcasts_to ->(comment) { [ comment.post, :comments ] },
                inserts_by: :append,
                target:     "comments"

  after_create_commit :notify_post_owner

  private

  def notify_post_owner
    return if user_id == post.user_id

    NotificationCreator.call(
      recipient:  post.user,
      actor:      user,
      notifiable: self,
      kind:       "comment",
      body:       "@#{user.username} comentó en '#{post.title}'"
    )
  end
end
