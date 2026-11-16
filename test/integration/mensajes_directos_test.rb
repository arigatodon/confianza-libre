require "test_helper"

class MensajesDirectosTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    setup_economy!
    @ana  = create_user(username: "ana")
    @beto = create_user(username: "beto")
  end

  test "desde el perfil se abre una conversación única entre dos personas" do
    sign_in_as @ana
    assert_difference "Conversation.count", 1 do
      post conversations_path(user_id: @beto.id)
    end
    conversation = Conversation.last
    assert_redirected_to conversation_path(conversation)

    # Reintentar (en cualquier orden) reusa la misma conversación.
    assert_no_difference "Conversation.count" do
      post conversations_path(user_id: @beto.id)
    end
    sign_in_as @beto
    assert_no_difference "Conversation.count" do
      post conversations_path(user_id: @ana.id)
    end
  end

  test "mandar un mensaje notifica al otro sin duplicar avisos" do
    conversation = Conversation.between!(@ana, @beto)
    sign_in_as @ana

    assert_difference "@beto.notifications.count", 1 do
      post conversation_direct_messages_path(conversation),
           params: { direct_message: { body: "Hola Beto, ¿tenés la escalera?" } }
      post conversation_direct_messages_path(conversation),
           params: { direct_message: { body: "Es para el sábado" } }
    end
    assert_equal 2, conversation.direct_messages.count
    assert conversation.reload.last_message_at.present?
  end

  test "entrar al chat marca las notificaciones de esa conversación como leídas" do
    conversation = Conversation.between!(@ana, @beto)
    conversation.direct_messages.create!(user: @ana, body: "¿Andás por ahí?")
    assert @beto.notifications.unread.where(notifiable: conversation).exists?

    sign_in_as @beto
    get conversation_path(conversation)
    assert_response :success
    assert_not @beto.notifications.unread.where(notifiable: conversation).exists?
  end

  test "nadie entra a una conversación ajena ni conversa consigo mismo" do
    conversation = Conversation.between!(@ana, @beto)
    intruso = create_user(username: "intruso")

    sign_in_as intruso
    get conversation_path(conversation)
    assert_redirected_to conversations_path

    post conversations_path(user_id: intruso.id)
    assert_no_difference "Conversation.count" do
      post conversations_path(user_id: intruso.id)
    end
  end

  test "sin email verificado no se mandan mensajes" do
    fantasma = create_user(username: "fantasmin", email_verified: false)
    conversation = Conversation.between!(@ana, fantasma)
    message = conversation.direct_messages.build(user: fantasma, body: "spam spam")
    assert_not message.valid?
    assert_match(/verifica tu email/, message.errors.full_messages.to_sentence)
  end

  test "el primer mensaje dispara un correo de aviso al receptor" do
    conversation = Conversation.between!(@ana, @beto)

    assert_enqueued_emails 1 do
      conversation.direct_messages.create!(user: @ana, body: "¡Hola! ¿Seguís vendiendo pan?")
    end

    mail = DirectMessageMailer.new_message(conversation.direct_messages.last)
    assert_equal [ @beto.email_address ], mail.to
    assert_match(/@ana te escribió/, mail.subject)
    assert_includes mail.html_part.body.to_s, "¿Seguís vendiendo pan?"
  end

  test "el correo se tope a uno por conversación dentro de la ventana" do
    conversation = Conversation.between!(@ana, @beto)
    DirectMessage.email_throttle_cache = ActiveSupport::Cache::MemoryStore.new

    assert_enqueued_emails 1 do
      conversation.direct_messages.create!(user: @ana, body: "Primer mensaje, avisa")
      conversation.direct_messages.create!(user: @ana, body: "Segundo seguido, no avisa")
    end
  ensure
    DirectMessage.email_throttle_cache = nil
  end

  test "la bandeja lista las conversaciones con el último mensaje" do
    conversation = Conversation.between!(@ana, @beto)
    conversation.direct_messages.create!(user: @beto, body: "Te debo las semillas")

    sign_in_as @ana
    get conversations_path
    assert_response :success
    assert_includes response.body, "@beto"
    assert_includes response.body, "Te debo las semillas"
  end
end
