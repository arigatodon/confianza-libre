# Empuja una Notification a todos los dispositivos suscritos del recipient.
# Si las claves VAPID no están configuradas (dev/test) no hace nada.
# Suscripciones vencidas o inválidas se eliminan solas.
class PushNotificationJob < ApplicationJob
  queue_as :default

  # Errores de red contra el push service: reintentar, no perder el aviso.
  retry_on Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNRESET,
           wait: :polynomially_longer, attempts: 3

  def perform(notification_id)
    return if ENV["VAPID_PUBLIC_KEY"].blank? || ENV["VAPID_PRIVATE_KEY"].blank?

    notification = Notification.find_by(id: notification_id)
    return if notification.nil? || notification.read?

    payload = {
      title:   "Confianza",
      options: {
        body: notification.body,
        icon: "/icon.png",
        data: { path: notification.link_path || "/notifications" }
      }
    }.to_json

    notification.recipient.push_subscriptions.find_each do |subscription|
      WebPush.payload_send(
        message:  payload,
        endpoint: subscription.endpoint,
        p256dh:   subscription.p256dh,
        auth:     subscription.auth,
        vapid: {
          subject:     "mailto:no-reply@confianza.world",
          public_key:  ENV["VAPID_PUBLIC_KEY"],
          private_key: ENV["VAPID_PRIVATE_KEY"]
        }
      )
    rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription, WebPush::Unauthorized
      subscription.destroy
    rescue WebPush::ResponseError => e
      Rails.logger.warn("[PushNotificationJob] #{e.class}: #{e.message}")
    end
  end
end
