require "test_helper"

class TypingChannelTest < ActionCable::Channel::TestCase
  setup do
    setup_economy!
    @sender   = create_user(username: "sndt")
    @receiver = create_user(username: "rcvt")
    @stranger = create_user(username: "strgr")
    @post        = create_post(user: @receiver)
    @interaction = create_interaction(post: @post, sender: @sender, receiver: @receiver)
  end

  test "participante puede suscribirse" do
    stub_connection current_user: @sender
    subscribe interaction_id: @interaction.id
    assert subscription.confirmed?
    assert_has_stream "typing:interaction:#{@interaction.id}"
  end

  test "rechaza a quien no participa" do
    stub_connection current_user: @stranger
    subscribe interaction_id: @interaction.id
    assert subscription.rejected?
  end

  test "rechaza si la interaction no existe" do
    stub_connection current_user: @sender
    subscribe interaction_id: -1
    assert subscription.rejected?
  end

  test "start retransmite payload con user_id y username" do
    stub_connection current_user: @sender
    subscribe interaction_id: @interaction.id

    expected = { event: "start", user_id: @sender.id, username: @sender.username }
    assert_broadcast_on("typing:interaction:#{@interaction.id}", expected) do
      perform :start
    end
  end

  test "stop retransmite event stop" do
    stub_connection current_user: @receiver
    subscribe interaction_id: @interaction.id

    expected = { event: "stop", user_id: @receiver.id, username: @receiver.username }
    assert_broadcast_on("typing:interaction:#{@interaction.id}", expected) do
      perform :stop
    end
  end
end
