require "test_helper"

class PushTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    setup_economy!
    @ana = create_user(username: "anapush")
  end

  test "el navegador registra su suscripción push" do
    sign_in_as @ana
    assert_difference "PushSubscription.count", 1 do
      post push_subscriptions_path, params: {
        endpoint: "https://fcm.googleapis.com/fcm/send/abc123",
        p256dh: "clave-p256dh", auth: "clave-auth"
      }, as: :json
    end
    assert_response :created

    # Re-suscribirse con el mismo endpoint no duplica (lo actualiza).
    assert_no_difference "PushSubscription.count" do
      post push_subscriptions_path, params: {
        endpoint: "https://fcm.googleapis.com/fcm/send/abc123",
        p256dh: "clave-nueva", auth: "auth-nueva"
      }, as: :json
    end
    assert_equal "clave-nueva", PushSubscription.last.p256dh
  end

  test "una notificación encola el push sólo si hay suscripciones" do
    beto = create_user(username: "betopush")

    assert_no_enqueued_jobs only: PushNotificationJob do
      NotificationCreator.call(recipient: beto, notifiable: @ana, kind: "news", body: "sin push")
    end

    beto.push_subscriptions.create!(endpoint: "https://x/y", p256dh: "k", auth: "a")
    assert_enqueued_with job: PushNotificationJob do
      NotificationCreator.call(recipient: beto, notifiable: @ana, kind: "news", body: "con push")
    end
  end

  test "el job no hace nada sin claves VAPID configuradas" do
    @ana.push_subscriptions.create!(endpoint: "https://x/z", p256dh: "k", auth: "a")
    n = NotificationCreator.call(recipient: @ana, notifiable: @ana, kind: "news", body: "hola")
    assert_nothing_raised { PushNotificationJob.perform_now(n.id) }
  end

  test "el service worker y el manifest se sirven" do
    get pwa_service_worker_path(format: :js)
    assert_response :success
    assert_includes response.body, "showNotification"

    get pwa_manifest_path(format: :json)
    assert_response :success
  end
end
