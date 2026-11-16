require "test_helper"

class MessageTest < ActiveSupport::TestCase
  setup do
    setup_economy!
    @sender   = create_user(username: "senderm")
    @receiver = create_user(username: "receiverm")
    @post     = create_post(user: @receiver)
    @interaction = create_interaction(post: @post, sender: @sender, receiver: @receiver, status: :in_progress)
  end

  test "valida que el user sea participante de la interaction" do
    outsider = create_user(username: "extrano")
    m = @interaction.messages.build(user: outsider, body: "Hola")
    refute m.valid?
    assert_match /no participas/, m.errors.full_messages.to_sentence
  end

  test "valida body presence y longitud max 2000" do
    m1 = @interaction.messages.build(user: @sender, body: "")
    refute m1.valid?

    m2 = @interaction.messages.build(user: @sender, body: "a" * 2001)
    refute m2.valid?
    assert_match /demasiado largo|too long/i, m2.errors.full_messages.to_sentence
  end

  test "bloquea mensajes en interaction canceled" do
    @interaction.update!(status: :canceled)
    m = @interaction.messages.build(user: @sender, body: "Algo")
    refute m.valid?
    assert_match /cancelada/, m.errors.full_messages.to_sentence
  end

  test "permite mensajes en disputed (para argumentar la disputa)" do
    @interaction.update!(status: :disputed)
    m = @interaction.messages.build(user: @sender, body: "Quiero explicar")
    assert m.valid?
  end

  test "notify_recipient: el primer mensaje crea Notification para la contraparte" do
    assert_difference -> { Notification.where(recipient: @receiver, kind: "new_message").count }, 1 do
      @interaction.messages.create!(user: @sender, body: "Primero")
    end
  end

  test "dedup: mensajes posteriores no spamean mientras la notif siga unread" do
    @interaction.messages.create!(user: @sender, body: "Uno")
    assert_no_difference -> { Notification.where(recipient: @receiver, kind: "new_message").count } do
      @interaction.messages.create!(user: @sender, body: "Dos")
      @interaction.messages.create!(user: @sender, body: "Tres")
    end
  end

  test "una nueva notif vuelve a generarse después de leer la anterior" do
    @interaction.messages.create!(user: @sender, body: "Uno")
    @receiver.notifications.where(kind: "new_message").update_all(read_at: Time.current)

    assert_difference -> { @receiver.notifications.where(kind: "new_message").count }, 1 do
      @interaction.messages.create!(user: @sender, body: "Dos, ya leíste el de antes")
    end
  end

  test "actor no recibe su propia notif" do
    assert_no_difference -> { @sender.notifications.where(kind: "new_message").count } do
      @interaction.messages.create!(user: @sender, body: "Hablo solo")
    end
  end
end
