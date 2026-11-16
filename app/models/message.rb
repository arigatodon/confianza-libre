class Message < ApplicationRecord
  belongs_to :interaction
  belongs_to :user
  has_many :reports, as: :reportable, dependent: :destroy

  validates :body, presence: true, length: { in: 1..2000 }
  validate  :user_is_participant
  validate  :interaction_is_active

  scope :ordered, -> { order(:created_at) }
  scope :visible, -> { where(hidden_at: nil) }

  def hidden_by_moderation?
    hidden_at.present?
  end

  # Turbo: cada Message creado se appendea al DOM #messages-<interaction_id>
  # de cualquier viewer suscrito a turbo_stream_from @interaction, :messages.
  # El partial messages/_message se renderiza neutralmente; la alineación
  # "míos / del otro" la aplica el cliente vía Stimulus (chat_controller).
  broadcasts_to ->(message) { [ message.interaction, :messages ] },
                inserts_by: :append,
                target:     ->(message) { "messages-#{message.interaction_id}" }

  after_create_commit :notify_recipient

  private

  # Dedup: si la contraparte ya tiene una notificación unread para esta
  # interaction, no creamos otra (evita N notifs por una ráfaga de mensajes).
  # Cuando la lea, vuelve a generarse para el próximo mensaje.
  def notify_recipient
    recipient = interaction.other_party(user)
    return unless recipient

    already = Notification.where(
      recipient:       recipient,
      notifiable_type: "Interaction",
      notifiable_id:   interaction_id,
      kind:            "new_message",
      read_at:         nil
    ).exists?
    return if already

    NotificationCreator.call(
      recipient:  recipient,
      actor:      user,
      notifiable: interaction,
      kind:       "new_message",
      body:       "@#{user.username} te escribió en '#{interaction.post.title}'"
    )
  end

  def user_is_participant
    return unless interaction && user_id
    return if [ interaction.sender_id, interaction.receiver_id ].include?(user_id)
    errors.add(:user, "no participas de esta interacción")
  end

  # Sin chat en canceled. En disputed sí permitimos para que las partes
  # puedan argumentar mientras se resuelve.
  def interaction_is_active
    return unless interaction
    return unless interaction.canceled?
    errors.add(:base, "la interacción está cancelada — no acepta mensajes")
  end
end
