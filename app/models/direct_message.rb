class DirectMessage < ApplicationRecord
  belongs_to :conversation
  belongs_to :user
  has_many :reports, as: :reportable, dependent: :destroy

  validates :body, presence: true, length: { in: 1..2000 }
  validate  :user_is_participant
  validate  :sender_has_verified_email

  scope :ordered, -> { order(:created_at) }
  scope :visible, -> { where(hidden_at: nil) }

  # Mismo patrón que el chat de interacciones: el broadcast appendea el
  # mensaje en el DOM de cualquier suscriptor a [conversation, :messages].
  broadcasts_to ->(message) { [ message.conversation, :messages ] },
                inserts_by: :append,
                target:     ->(message) { "messages-conv-#{message.conversation_id}" }

  # Tope de correos: máximo 1 por conversación cada 12 h hacia cada receptor.
  EMAIL_THROTTLE = 12.hours
  # Inyectable en tests (el cache de test es null_store y no tope nada).
  cattr_accessor :email_throttle_cache

  after_create_commit :touch_conversation
  after_create_commit :notify_recipient
  after_create_commit :email_recipient

  def hidden_by_moderation?
    hidden_at.present?
  end

  private

  def touch_conversation
    conversation.update_column(:last_message_at, created_at)
  end

  # Dedup: una sola notificación unread por conversación (como en interacciones).
  def notify_recipient
    recipient = conversation.other_party(user)
    return unless recipient

    already = Notification.where(
      recipient:       recipient,
      notifiable_type: "Conversation",
      notifiable_id:   conversation_id,
      kind:            "new_message",
      read_at:         nil
    ).exists?
    return if already

    NotificationCreator.call(
      recipient:  recipient,
      actor:      user,
      notifiable: conversation,
      kind:       "new_message",
      body:       "@#{user.username} te envió un mensaje directo"
    )
  end

  # Email de aviso con throttle propio (independiente de si leyó la campanita:
  # el correo es para quien NO está en la app). write con unless_exist
  # devuelve false si la key ya existía → dentro de la ventana, no se manda.
  def email_recipient
    recipient = conversation.other_party(user)
    return unless recipient

    cache = self.class.email_throttle_cache || Rails.cache
    throttle_key = "dm-email:#{conversation_id}:#{recipient.id}"
    return unless cache.write(throttle_key, 1, unless_exist: true, expires_in: EMAIL_THROTTLE)

    DirectMessageMailer.new_message(self).deliver_later
  end

  def user_is_participant
    return unless conversation && user_id
    return if conversation.participant?(user)
    errors.add(:user, "no participas de esta conversación")
  end

  # Anti-spam: sin email verificado no se escriben DMs (sí se reciben).
  def sender_has_verified_email
    return if user.nil? || !user.verification_unverified?
    errors.add(:base, "verifica tu email para enviar mensajes directos")
  end
end
