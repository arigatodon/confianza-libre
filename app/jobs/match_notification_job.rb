# Avisa (in-app + push) a la otra mitad del mercado cuando se publica un post.
# Idempotente: no repite el aviso a un mismo usuario por el mismo post, y
# respeta el tope diario gobernable `match_daily_cap`.
class MatchNotificationJob < ApplicationJob
  queue_as :default

  def perform(post_id)
    post = Post.find_by(id: post_id)
    return if post.nil? || !post.published? || post.hidden_by_moderation?

    cap = EconomicParameter.get_int("match_daily_cap", 5)

    MatchFinder.new(post).candidates.each do |user|
      next if already_notified?(user, post)
      next if cap.positive? && matches_today(user) >= cap

      NotificationCreator.call(
        recipient:  user,
        actor:      post.user,
        notifiable: post,
        kind:       "match",
        body:       body_for(post)
      )
    end
  end

  private

  # Máx. 1 aviso por usuario por post, aunque el job se reencole.
  def already_notified?(user, post)
    Notification.where(recipient_id: user.id, kind: "match", notifiable: post).exists?
  end

  def matches_today(user)
    Notification.discovery_count_today(user)
  end

  def body_for(post)
    verbo = post.pedido? ? "busca" : "ofrece"
    "@#{post.user.username} #{verbo} «#{post.title}» cerca tuyo · #{post.category.name}"
  end
end
