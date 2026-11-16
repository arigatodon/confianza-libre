# Avisa a los dueños de alertas guardadas (Fase 2.3) cuando se publica un post
# que las cumple. Se dispara al publicar (no por cron). Idempotente (máx. 1 por
# usuario y post) y respeta el tope diario global de avisos de descubrimiento.
class SavedSearchAlertJob < ApplicationJob
  queue_as :default

  def perform(post_id)
    post = Post.find_by(id: post_id)
    return if post.nil? || !post.published? || post.hidden_by_moderation?

    cap = EconomicParameter.get_int("match_daily_cap", 5)

    notified = []
    SavedSearch.where.not(user_id: post.user_id).includes(:user, :category).find_each do |search|
      user = search.user
      next if notified.include?(user.id)
      next unless search.matches?(post)
      next if already_notified?(user, post)
      next if cap.positive? && Notification.discovery_count_today(user) >= cap

      NotificationCreator.call(
        recipient:  user,
        actor:      post.user,
        notifiable: post,
        kind:       "saved_search",
        body:       body_for(post)
      )
      notified << user.id
    end
  end

  private

  def already_notified?(user, post)
    Notification.where(recipient_id: user.id, kind: "saved_search", notifiable: post).exists?
  end

  def body_for(post)
    verbo = post.pedido? ? "busca" : "ofrece"
    "Coincide con tu alerta: @#{post.user.username} #{verbo} «#{post.title}»"
  end
end
