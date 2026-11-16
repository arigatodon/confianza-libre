class Notification < ApplicationRecord
  belongs_to :recipient,  class_name: "User"
  belongs_to :actor,      class_name: "User", optional: true
  belongs_to :notifiable, polymorphic: true

  validates :kind, :body, presence: true

  scope :unread, -> { where(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  # Avisos de descubrimiento (matching de pedidos/ofertas + alertas guardadas):
  # comparten un mismo tope diario por usuario (match_daily_cap).
  DISCOVERY_KINDS = %w[match saved_search].freeze

  def self.discovery_count_today(user)
    where(recipient_id: user.id, kind: DISCOVERY_KINDS)
      .where(created_at: Time.current.beginning_of_day..).count
  end

  after_create_commit :broadcast_arrival
  after_create_commit :deliver_push
  after_update_commit :broadcast_badge_refresh, if: :saved_change_to_read_at?

  def read?
    read_at.present?
  end

  def mark_as_read!
    return if read?
    update!(read_at: Time.current)
  end

  # Refresca los badges del bell para un user sin requerir tocar cada
  # notification (útil después de update_all en el index).
  def self.refresh_badges_for(user)
    count = user.notifications.unread.count
    Turbo::StreamsChannel.broadcast_replace_to(
      [ user, :notifications ],
      target:  "bell-badge-side",
      partial: "shared/bell_badge_side",
      locals:  { count: count }
    )
    Turbo::StreamsChannel.broadcast_replace_to(
      [ user, :notifications ],
      target:  "bell-badge-top",
      partial: "shared/bell_badge_top",
      locals:  { count: count }
    )
  end

  # Adónde lleva el click. Resolvemos por tipo para que la lista no necesite
  # if/case en la vista.
  def link_path
    case notifiable
    when Interaction
      Rails.application.routes.url_helpers.interaction_path(notifiable_id)
    when Post
      Rails.application.routes.url_helpers.post_path(notifiable.slug || notifiable_id)
    when Review, Comment
      post = notifiable.post
      Rails.application.routes.url_helpers.post_path(post.slug || post.id)
    when Announcement
      Rails.application.routes.url_helpers.announcement_path(notifiable.slug)
    when Endorsement
      user = notifiable.endorsed
      Rails.application.routes.url_helpers.profile_path(user.username || user.id)
    when Proposal
      Rails.application.routes.url_helpers.proposal_path(notifiable)
    when IdentityVerification
      Rails.application.routes.url_helpers.settings_path
    when Conversation
      Rails.application.routes.url_helpers.conversation_path(notifiable_id)
    when Dispute
      Rails.application.routes.url_helpers.interaction_path(notifiable.interaction_id)
    when Report
      report_link_path(notifiable)
    end
  end

  def icon
    case kind
    when "interaction_started"  then "handshake"
    when "interaction_status"   then "swap_horiz"
    when "interaction_complete" then "task_alt"
    when "review_received"      then "star"
    when "comment"              then "chat"
    when "new_message"          then "forum"
    when "news"                 then "campaign"
    when "endorsement"          then "verified_user"
    when "match"                then "join_inner"
    when "saved_search"         then "notifications_active"
    when "identity_review"      then "fingerprint"
    when "moderation_role"      then "shield_person"
    when "dispute_response", "dispute_resolved" then "gavel"
    else                             "notifications"
    end
  end

  private

  # Un aviso de moderación lleva al contenido afectado (el autor siempre
  # puede ver lo propio, aunque esté oculto para el resto).
  def report_link_path(report)
    helpers = Rails.application.routes.url_helpers
    case report.reportable
    when Post          then helpers.post_path(report.reportable.slug || report.reportable_id)
    when Comment       then helpers.post_path(report.reportable.post.slug || report.reportable.post_id)
    when Message       then helpers.interaction_path(report.reportable.interaction_id)
    when DirectMessage then helpers.conversation_path(report.reportable.conversation_id)
    when User          then helpers.profile_path(report.reportable.username || report.reportable_id)
    end
  end

  def broadcast_arrival
    # 1. Prepend la nueva notif al listado de /notifications (si el viewer
    #    tiene esa página abierta, aparece sin F5).
    broadcast_prepend_to [ recipient, :notifications ],
                         target:  "notifications-list",
                         partial: "notifications/notification",
                         locals:  { notification: self }
    # 2. Refrescar ambos badges del bell.
    broadcast_badge_refresh
  end

  # Push al dispositivo (si el user activó las notificaciones). El job
  # no hace nada si no hay claves VAPID o no hay suscripciones.
  def deliver_push
    return unless recipient.push_subscriptions.exists?
    PushNotificationJob.perform_later(id)
  end

  def broadcast_badge_refresh
    count = recipient.notifications.unread.count
    broadcast_replace_to [ recipient, :notifications ],
                         target:  "bell-badge-side",
                         partial: "shared/bell_badge_side",
                         locals:  { count: count }
    broadcast_replace_to [ recipient, :notifications ],
                         target:  "bell-badge-top",
                         partial: "shared/bell_badge_top",
                         locals:  { count: count }
  end
end
