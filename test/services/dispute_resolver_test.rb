require "test_helper"

class DisputeResolverTest < ActiveSupport::TestCase
  setup do
    setup_economy!

    @sender    = create_user(username: "resdr")
    @receiver  = create_user(username: "resrc")
    @moderator = create_user(username: "resmod")
    @moderator.grant_moderation!

    @post = create_post(user: @receiver, latitude: -33.45, longitude: -70.65)
    @interaction = create_interaction(post: @post, sender: @sender, receiver: @receiver,
                                       status: :in_progress, agreed_credits: 40)
    @dispute = Dispute.create!(interaction: @interaction, opener: @sender, argument: "a" * 30)
  end

  test "veredicto complete cierra la interacción y transfiere el monto acordado" do
    result = DisputeResolver.call(dispute: @dispute, moderator: @moderator, verdict: "complete")

    assert result.ok?
    assert @interaction.reload.completed?
    assert @dispute.reload.resolved?
    assert_equal "complete", @dispute.verdict
    assert_equal 40, @dispute.resolution_amount
    assert @interaction.credit_transaction.present?
  end

  test "veredicto partial transfiere solo el monto ajustado" do
    result = DisputeResolver.call(dispute: @dispute, moderator: @moderator, verdict: "partial", amount: 15)

    assert result.ok?
    assert @interaction.reload.completed?
    assert_equal 15, @dispute.reload.resolution_amount
    assert_equal 15, @interaction.credit_transaction.total_amount
  end

  test "veredicto cancel no mueve créditos y cancela la interacción" do
    result = DisputeResolver.call(dispute: @dispute, moderator: @moderator, verdict: "cancel")

    assert result.ok?
    assert @interaction.reload.canceled?
    assert_nil @interaction.credit_transaction
    assert_nil @dispute.reload.resolution_amount
  end

  test "rechaza un monto parcial mayor al acordado" do
    result = DisputeResolver.call(dispute: @dispute, moderator: @moderator, verdict: "partial", amount: 999)

    assert_not result.ok?
    assert_equal :invalid_amount, result.error
    refute @interaction.reload.completed?
  end

  test "rechaza si quien resuelve no es moderador" do
    @moderator.revoke_moderation!
    result = DisputeResolver.call(dispute: @dispute, moderator: @moderator, verdict: "complete")

    assert_not result.ok?
    assert_equal :unauthorized, result.error
  end

  test "un moderador no puede resolver una disputa donde es parte" do
    @sender.grant_moderation!
    result = DisputeResolver.call(dispute: @dispute, moderator: @sender, verdict: "complete")
    assert_equal :cannot_resolve_own, result.error
  end

  test "no se puede resolver una disputa ya resuelta" do
    DisputeResolver.call(dispute: @dispute, moderator: @moderator, verdict: "cancel")
    result = DisputeResolver.call(dispute: @dispute.reload, moderator: @moderator, verdict: "complete")
    assert_equal :already_resolved, result.error
  end

  test "notifica a ambas partes al resolver" do
    assert_difference -> { Notification.where(kind: "dispute_resolved").count }, 2 do
      DisputeResolver.call(dispute: @dispute, moderator: @moderator, verdict: "cancel")
    end
  end
end
