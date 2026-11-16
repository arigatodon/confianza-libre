require "test_helper"

class DecayInactiveLimitsJobTest < ActiveJob::TestCase
  setup do
    setup_economy!
    @sender   = create_user(username: "deudor")
    @other    = create_user(username: "otro")
    # Llevar al sender a saldo negativo vía una transferencia real.
    create_completed_interaction(sender: @sender, receiver: @other, agreed_credits: 40)
    @sender.reload
    assert @sender.credit_account.cached_balance.negative?, "setup: sender debería terminar en negativo"
  end

  test "decae credit_floor cuando hay deuda y sin reviews positivas recientes" do
    original_floor = @sender.credit_floor
    DecayInactiveLimitsJob.perform_now

    assert_operator @sender.reload.credit_floor, :<, original_floor,
      "credit_floor debería decaer (era #{original_floor})"
  end

  test "skip cuando recibió review positiva en los últimos decay_check_days días" do
    # Le dejamos una review score 5 (≥ threshold 4).
    i = Interaction.completed.first
    create_review(interaction: i, reviewer: i.other_party(@sender), score: 5)
    original_floor = @sender.credit_floor

    DecayInactiveLimitsJob.perform_now

    assert_equal original_floor, @sender.reload.credit_floor,
      "una review positiva reciente debe evitar el decay"
  end

  test "no baja credit_floor por debajo de |cached_balance| (no condonamos deuda)" do
    # Forzar credit_floor cerca del piso de deuda — el deudor tiene -38 (40 - burn - territory).
    deuda = @sender.credit_account.cached_balance.abs
    @sender.update_column(:credit_floor, deuda)  # piso = deuda exacta
    DecayInactiveLimitsJob.perform_now
    assert_equal deuda, @sender.reload.credit_floor,
      "el floor no puede bajar de |cached_balance|"
  end

  test "skip cuando balance ≥ 0 aunque no haya reviews positivas" do
    receiver = User.find_by(username: "otro")
    original_floor = receiver.credit_floor
    DecayInactiveLimitsJob.perform_now
    assert_equal original_floor, receiver.reload.credit_floor,
      "sin deuda no hay decay"
  end

  test "candidates filtra en SQL: solo deudores con floor > 0 y sin review positiva" do
    candidates = DecayInactiveLimitsJob.candidates(4, 90.days.ago)
    assert_includes candidates, @sender
    assert_not_includes candidates, @other, "sin deuda no es candidato"

    # Con una review positiva reciente sale de la lista sin cargarlo en Ruby.
    i = Interaction.completed.first
    create_review(interaction: i, reviewer: i.other_party(@sender), score: 5)
    assert_not_includes DecayInactiveLimitsJob.candidates(4, 90.days.ago), @sender
  end
end
