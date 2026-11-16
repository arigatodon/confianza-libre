require "test_helper"

class DisputeTest < ActiveSupport::TestCase
  setup do
    setup_economy!
    @sender   = create_user(username: "dsender")
    @receiver = create_user(username: "dreceiver")
    @post     = create_post(user: @receiver)
    @interaction = create_interaction(post: @post, sender: @sender, receiver: @receiver, status: :in_progress)
  end

  def build_dispute(**attrs)
    Dispute.new(
      { interaction: @interaction, opener: @sender, argument: "a" * 30 }.merge(attrs)
    )
  end

  test "válida con argumento de al menos 30 caracteres y opener participante" do
    d = build_dispute
    assert d.valid?
  end

  test "inválida si el argumento tiene menos de 30 caracteres" do
    d = build_dispute(argument: "muy corto")
    refute d.valid?
    assert_match /demasiado corto|corto/, d.errors.full_messages.to_sentence.downcase
  end

  test "inválida si el opener no es parte de la interacción" do
    ajeno = create_user(username: "ajeno")
    d = build_dispute(opener: ajeno)
    refute d.valid?
    assert_match /solo las partes/, d.errors.full_messages.to_sentence.downcase
  end

  test "inválida si la interacción no está en un estado disputable" do
    @interaction.update_columns(status: Interaction::STATUSES[:completed])
    d = build_dispute
    refute d.valid?
    assert_match /aceptada o en curso/, d.errors.full_messages.to_sentence.downcase
  end

  test "no permite dos disputas para la misma interacción" do
    build_dispute.save!
    dup = build_dispute
    refute dup.valid?
    assert_match /ya tiene una disputa/, dup.errors.full_messages.to_sentence.downcase
  end

  test "counterpart devuelve la otra parte de la interacción" do
    d = build_dispute
    assert_equal @receiver, d.counterpart

    d2 = build_dispute(opener: @receiver)
    assert_equal @sender, d2.counterpart
  end

  test "stale? es true recién a partir del umbral gobernable de días" do
    d = build_dispute
    d.save!
    refute d.stale?

    d.update_column(:created_at, 8.days.ago)
    assert d.stale?
  end

  test "exige response al pasar a responded" do
    d = build_dispute
    d.save!
    d.status = :responded
    refute d.valid?
    d.response = "Mi versión de los hechos, con más de una palabra."
    assert d.valid?
  end
end
