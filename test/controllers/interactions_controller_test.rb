require "test_helper"

class InteractionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    setup_economy!
    @sender   = create_user(username: "icsdr")
    @receiver = create_user(username: "icrcv")
    @post     = create_post(user: @receiver)
    @interaction = create_interaction(post: @post, sender: @sender, receiver: @receiver,
                                       status: :in_progress, agreed_credits: 20)
  end

  test "abrir disputa con argumento válido crea el registro y pasa la interacción a disputed" do
    sign_in_as(@sender)
    patch dispute_interaction_path(@interaction), params: { dispute: { argument: "a" * 30 } }

    assert_redirected_to @interaction
    assert @interaction.reload.disputed?
    assert @interaction.dispute.present?
    assert_equal @sender, @interaction.dispute.opener
  end

  test "abrir disputa con argumento corto no crea el registro ni cambia el estado" do
    sign_in_as(@sender)
    patch dispute_interaction_path(@interaction), params: { dispute: { argument: "corto" } }

    assert_redirected_to @interaction
    refute @interaction.reload.disputed?
    assert_nil @interaction.dispute
  end

  test "no se puede abrir disputa dos veces sobre la misma interacción" do
    sign_in_as(@sender)
    patch dispute_interaction_path(@interaction), params: { dispute: { argument: "a" * 30 } }
    patch dispute_interaction_path(@interaction), params: { dispute: { argument: "b" * 30 } }

    assert_equal 1, Dispute.where(interaction: @interaction).count
  end

  test "quien no participa de la interacción no puede abrir disputa" do
    ajeno = create_user(username: "icajeno")
    sign_in_as(ajeno)
    patch dispute_interaction_path(@interaction), params: { dispute: { argument: "a" * 30 } }

    refute @interaction.reload.disputed?
  end

  test "la contraparte puede responder la disputa abierta" do
    sign_in_as(@sender)
    patch dispute_interaction_path(@interaction), params: { dispute: { argument: "a" * 30 } }

    sign_in_as(@receiver)
    patch respond_dispute_interaction_path(@interaction), params: { dispute: { response: "mi versión de los hechos" } }

    assert_redirected_to @interaction
    dispute = @interaction.reload.dispute
    assert dispute.responded?
    assert_equal "mi versión de los hechos", dispute.response
  end

  test "el opener no puede responder su propia disputa" do
    sign_in_as(@sender)
    patch dispute_interaction_path(@interaction), params: { dispute: { argument: "a" * 30 } }
    patch respond_dispute_interaction_path(@interaction), params: { dispute: { response: "algo" } }

    refute @interaction.reload.dispute.responded?
  end
end
