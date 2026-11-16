class Interaction < ApplicationRecord
  STATUSES = {
    requested:   0,
    accepted:    1,
    in_progress: 2,
    completed:   3,
    canceled:    4,
    disputed:    5,
    negotiating: 6
  }.freeze

  OPEN_STATUSES = %w[requested negotiating accepted in_progress].freeze

  STATUS_LABELS_ES = {
    "requested"   => "Solicitada",
    "accepted"    => "Aceptada",
    "in_progress" => "En curso",
    "completed"   => "Cerrada",
    "canceled"    => "Cancelada",
    "disputed"    => "En disputa",
    "negotiating" => "En negociación"
  }.freeze

  STATUS_ICONS = {
    "requested"   => "front_hand",
    "accepted"    => "thumb_up",
    "in_progress" => "autorenew",
    "completed"   => "task_alt",
    "canceled"    => "block",
    "disputed"    => "gavel",
    "negotiating" => "compare_arrows"
  }.freeze

  enum :status, STATUSES

  belongs_to :post
  belongs_to :sender,   class_name: "User", inverse_of: :interactions_sent
  belongs_to :receiver, class_name: "User", inverse_of: :interactions_received

  has_one :credit_transaction, dependent: :restrict_with_error
  has_one :dispute, dependent: :destroy

  has_many :reviews,  dependent: :destroy
  has_many :messages, dependent: :destroy

  validates :agreed_credits, numericality: { greater_than_or_equal_to: 0 }
  validate :sender_is_not_receiver
  validate :sender_within_open_interactions_cap, on: :create

  after_create_commit  :notify_creation
  after_update_commit  :notify_status_change, if: :saved_change_to_status?
  after_update_commit  :enqueue_level_recalc, if: -> { saved_change_to_status? && completed? }

  # Realtime: cualquier update en la interaction (status, confirmaciones,
  # agreed_credits, etc.) hace que cada viewer de /interactions/:id morphee
  # su DOM contra una versión fresca renderizada para su perspectiva.
  after_update_commit :broadcast_show_refresh

  def broadcast_show_refresh
    broadcast_refresh_later_to(self)
  end

  def other_party(user)
    return nil unless user
    user.id == sender_id ? receiver : sender
  end

  def reviewed_by?(user)
    return false unless user
    reviews.where(reviewer_id: user.id).exists?
  end

  def review_pending_for?(user)
    return false unless completed?
    return false unless user && [ sender_id, receiver_id ].include?(user.id)
    !reviewed_by?(user)
  end

  def confirmed_by?(user)
    return false unless user
    user.id == sender_id ? sender_completed_at.present? : receiver_completed_at.present?
  end

  def confirmation_field_for(user)
    return nil unless user && [ sender_id, receiver_id ].include?(user.id)
    user.id == sender_id ? :sender_completed_at : :receiver_completed_at
  end

  def both_confirmed?
    sender_completed_at.present? && receiver_completed_at.present?
  end

  def status_label_es
    STATUS_LABELS_ES[status] || status.to_s.humanize
  end

  def status_icon
    STATUS_ICONS[status] || "help"
  end

  # Quién "tiene la pelota" en una negociación.
  #   requested   → espera al receiver (responder al primer ofrecimiento).
  #   negotiating → espera al sender (responder a la contrapropuesta).
  def awaiting_response_from
    case status
    when "requested"   then receiver
    when "negotiating" then sender
    end
  end

  def negotiation_open?
    requested? || negotiating?
  end

  private

  def sender_is_not_receiver
    return unless sender_id == receiver_id

    errors.add(:receiver_id, "el emisor y el receptor no pueden ser el mismo usuario")
  end

  # Anti-spam / anti-multicuenta: un usuario L1 no puede tener más de N
  # interactions abiertas (requested / negotiating / accepted / in_progress)
  # simultáneamente como sender. Threshold tunable vía `economic_parameters`;
  # 0 desactiva el límite. Niveles L2+ están exentos.
  def sender_within_open_interactions_cap
    return unless sender
    return unless sender.level.to_i <= 1

    cap = EconomicParameter.get_int("max_open_interactions_l1", 3)
    return if cap <= 0

    open_count = sender.interactions_sent.where(status: OPEN_STATUSES).count
    return if open_count < cap

    errors.add(:base,
      "Tienes #{open_count} interacciones abiertas como iniciador. " \
      "El máximo para tu nivel es #{cap}. Cierra o cancela alguna antes de iniciar otra.")
  end

  def enqueue_level_recalc
    RecalculateUserLevelJob.perform_later(sender_id)
    RecalculateUserLevelJob.perform_later(receiver_id)
  end

  def notify_creation
    NotificationCreator.call(
      recipient:  receiver,
      actor:      sender,
      notifiable: self,
      kind:       "interaction_started",
      body:       "@#{sender.username} inició una interacción en '#{post.title}'" +
                  (agreed_credits.to_i.positive? ? " — ofrece #{agreed_credits} C" : "")
    )
    InteractionMailer.requested(self).deliver_later
  end

  # En las transiciones, el "actor" es quien clickeó el botón en el controller.
  # Tomamos Current.session.user — si no hay sesión (cambio desde consola / job)
  # no notificamos para no spammear con avisos sin actor claro.
  def notify_status_change
    actor = Current.session&.user
    return unless actor
    recipient = other_party(actor)
    return unless recipient

    body =
      case status
      when "accepted"    then "@#{actor.username} aceptó tu propuesta de #{agreed_credits} C"
      when "negotiating" then "@#{actor.username} contrapropuso #{agreed_credits} C"
      when "requested"   then "@#{actor.username} contrapropuso #{agreed_credits} C"
      when "in_progress" then "@#{actor.username} marcó la interacción como en curso"
      when "canceled"    then "@#{actor.username} canceló la interacción"
      when "disputed"    then "@#{actor.username} abrió una disputa"
      when "completed"   then "Se cerró la interacción" + (agreed_credits.to_i.positive? ? " — recibiste #{credit_transaction&.total_amount.to_i - credit_transaction&.burn_amount.to_i - credit_transaction&.community_amount.to_i} C" : "")
      end
    return unless body

    NotificationCreator.call(
      recipient: recipient, actor: actor, notifiable: self,
      kind: (completed? ? "interaction_complete" : "interaction_status"),
      body: body
    )
  end
end
