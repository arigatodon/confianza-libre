require "test_helper"

# Tests del fan-out automático: cada modelo dispara la Notification correcta
# cuando ocurre el evento. Cubre Interaction, Review y Comment hooks.
class NotificationFlowTest < ActiveSupport::TestCase
  setup do
    setup_economy!
    @sender   = create_user(username: "actor")
    @receiver = create_user(username: "target")
    @post     = create_post(user: @receiver)
  end

  test "Interaction.create notifica al receiver con kind interaction_started" do
    assert_difference -> { @receiver.notifications.where(kind: "interaction_started").count }, 1 do
      create_interaction(post: @post, sender: @sender, receiver: @receiver, agreed_credits: 30)
    end
    notif = @receiver.notifications.where(kind: "interaction_started").last
    assert_includes notif.body, "@actor"
    assert_equal @sender, notif.actor
    assert_equal "Interaction", notif.notifiable_type
  end

  test "actor no se notifica a sí mismo en interaction_started" do
    assert_no_difference -> { @sender.notifications.where(kind: "interaction_started").count } do
      create_interaction(post: @post, sender: @sender, receiver: @receiver, agreed_credits: 30)
    end
  end

  test "Review.create notifica al reviewed_user con kind review_received" do
    i = create_completed_interaction(sender: @sender, receiver: @receiver, agreed_credits: 30)

    assert_difference -> { @sender.notifications.where(kind: "review_received").count }, 1 do
      create_review(interaction: i, reviewer: @receiver, score: 5)
    end
  end

  test "Comment.create notifica al dueño del post si no es el autor del comment" do
    visitor = create_user(username: "visitor")

    assert_difference -> { @receiver.notifications.where(kind: "comment").count }, 1 do
      @post.comments.create!(user: visitor, body: "Buen aviso")
    end
  end

  test "Comment del propio dueño no genera notification" do
    assert_no_difference -> { @receiver.notifications.where(kind: "comment").count } do
      @post.comments.create!(user: @receiver, body: "Comento mi propio post")
    end
  end

  test "NotificationCreator.call salta si recipient == actor" do
    assert_no_difference -> { Notification.count } do
      NotificationCreator.call(
        recipient: @sender, actor: @sender,
        notifiable: @post, kind: "test", body: "no debería crearse"
      )
    end
  end

  test "Notification#mark_as_read! cambia read_at" do
    n = NotificationCreator.call(recipient: @receiver, actor: @sender,
                                  notifiable: @post, kind: "test", body: "ok")
    refute n.read?
    n.mark_as_read!
    assert n.reload.read?
  end
end
