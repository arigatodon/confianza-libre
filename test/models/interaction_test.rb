require "test_helper"

class InteractionTest < ActiveSupport::TestCase
  setup do
    setup_economy!
    @sender   = create_user(username: "senderi")
    @receiver = create_user(username: "receiveri")
    @post     = create_post(user: @receiver)
  end

  test "rechaza si sender == receiver" do
    i = @post.interactions.build(sender: @sender, receiver: @sender, agreed_credits: 10)
    refute i.valid?
    assert_match /no pueden ser el mismo/, i.errors.full_messages.to_sentence
  end

  test "other_party devuelve la contraparte del user dado" do
    i = create_interaction(post: @post, sender: @sender, receiver: @receiver)
    assert_equal @receiver, i.other_party(@sender)
    assert_equal @sender,   i.other_party(@receiver)
  end

  test "confirmed_by? y both_confirmed? para el cierre dual" do
    i = create_interaction(post: @post, sender: @sender, receiver: @receiver, status: :in_progress)
    refute i.confirmed_by?(@sender)
    refute i.both_confirmed?

    i.update!(sender_completed_at: Time.current)
    assert i.confirmed_by?(@sender)
    refute i.confirmed_by?(@receiver)
    refute i.both_confirmed?

    i.update!(receiver_completed_at: Time.current)
    assert i.both_confirmed?
  end

  test "awaiting_response_from alterna entre receiver (requested) y sender (negotiating)" do
    i = create_interaction(post: @post, sender: @sender, receiver: @receiver, status: :requested)
    assert_equal @receiver, i.awaiting_response_from
    i.status = :negotiating
    assert_equal @sender, i.awaiting_response_from
    i.status = :accepted
    assert_nil i.awaiting_response_from
  end

  test "rate limit: L1 con cap de interactions abiertas alcanzado no puede crear más" do
    set_param("max_open_interactions_l1", "2")

    assert_equal 1, @sender.level

    # 2 abiertas como sender — toca el cap exacto.
    other_receiver = create_user(username: "otherrec")
    p2 = create_post(user: other_receiver)
    create_interaction(post: @post, sender: @sender, receiver: @receiver, status: :requested)
    create_interaction(post: p2,    sender: @sender, receiver: other_receiver, status: :in_progress)

    extra_receiver = create_user(username: "extrarec")
    p3 = create_post(user: extra_receiver)
    i3 = p3.interactions.build(sender: @sender, receiver: extra_receiver, agreed_credits: 0)
    refute i3.valid?, "debería rechazar la tercera"
    assert_match /máximo para tu nivel/i, i3.errors.full_messages.to_sentence
  end

  test "rate limit: status cerrados (completed/canceled/disputed) no cuentan al cap" do
    set_param("max_open_interactions_l1", "1")

    other_receiver = create_user(username: "or2")
    p2 = create_post(user: other_receiver)
    # 3 interactions cerradas: no deberían contar.
    create_interaction(post: @post, sender: @sender, receiver: @receiver,       status: :canceled)
    create_interaction(post: @post, sender: @sender, receiver: @receiver,       status: :disputed)
    create_interaction(post: p2,    sender: @sender, receiver: other_receiver,  status: :requested).update_columns(status: 3) # completed

    # La siguiente abierta debería pasar (0 abiertas / cap 1).
    p3 = create_post(user: other_receiver, title: "Otro")
    i = p3.interactions.create(sender: @sender, receiver: other_receiver, agreed_credits: 0)
    assert i.persisted?, i.errors.full_messages.to_sentence
  end

  test "rate limit: usuarios L2+ están exentos" do
    set_param("max_open_interactions_l1", "1")

    @sender.update_columns(level: 2)
    other_receiver = create_user(username: "or3")
    p2 = create_post(user: other_receiver)
    create_interaction(post: @post, sender: @sender, receiver: @receiver, status: :requested)

    p3 = create_post(user: other_receiver, title: "Otro2")
    i = p3.interactions.create(sender: @sender, receiver: other_receiver, agreed_credits: 0)
    assert i.persisted?, "L2 debería poder pasar el cap de L1"
  end

  test "rate limit: cap = 0 desactiva la validación" do
    set_param("max_open_interactions_l1", "0")

    other_receiver = create_user(username: "or4")
    5.times do |n|
      p = create_post(user: other_receiver, title: "P#{n}")
      i = p.interactions.create(sender: @sender, receiver: other_receiver, agreed_credits: 0)
      assert i.persisted?, "cap 0 debería desactivar — fallo en iter #{n}: #{i.errors.full_messages.to_sentence}"
    end
  end

  test "review_pending_for? sólo válido en completed y sin review previa" do
    i = create_interaction(post: @post, sender: @sender, receiver: @receiver, status: :in_progress)
    refute i.review_pending_for?(@sender), "in_progress no debería tener review pendiente"

    i.update_columns(status: 3)
    assert i.review_pending_for?(@sender)

    create_review(interaction: i, reviewer: @sender, score: 4)
    refute i.review_pending_for?(@sender)
    # El receiver todavía no evaluó.
    assert i.review_pending_for?(@receiver)
  end
end
