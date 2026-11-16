require "test_helper"

# Recorre el camino crítico de la economía v0.2 desde la perspectiva HTTP.
# Sin browser (no es system test) — más rápido y cubre rutas, controllers,
# modelos, callbacks, jobs y broadcasts sin tocar JS.
class HappyPathTest < ActionDispatch::IntegrationTest
  setup do
    setup_economy!
    @receiver = create_user(username: "vendedor")
    @sender   = create_user(username: "comprador")
    @post     = create_post(user: @receiver, title: "Curso de Ruby", suggested_credits: 30)
  end

  test "publicación → interacción → negociación → confirmación dual → ledger balanceado → review" do
    # 1. Sender inicia interacción con 25 C (contraofreciendo el sugerido de 30).
    sign_in_as(@sender)
    post post_interactions_path(@post), params: { interaction: { agreed_credits: 25 } }
    interaction = Interaction.last
    assert_redirected_to interaction_path(interaction)
    assert_equal "requested", interaction.status
    assert_equal 25,          interaction.agreed_credits
    sign_out

    # 2. Receiver contrapropone 30.
    sign_in_as(@receiver)
    patch counter_interaction_path(interaction), params: { interaction: { agreed_credits: 30 } }
    assert_equal "negotiating", interaction.reload.status
    assert_equal 30,            interaction.agreed_credits
    sign_out

    # 3. Sender acepta los 30.
    sign_in_as(@sender)
    patch accept_interaction_path(interaction)
    assert_equal "accepted", interaction.reload.status

    # 4. Sender pasa a in_progress.
    patch start_interaction_path(interaction)
    assert_equal "in_progress", interaction.reload.status

    # 5. Sender confirma — la otra parte aún no, así que sigue in_progress.
    patch confirm_interaction_path(interaction)
    assert_equal "in_progress", interaction.reload.status
    assert interaction.sender_completed_at.present?
    assert_nil interaction.receiver_completed_at
    sign_out

    # 6. Receiver confirma → CreditTransfer dispara y status=completed.
    sign_in_as(@receiver)
    patch confirm_interaction_path(interaction)
    interaction.reload
    assert_equal "completed", interaction.status
    assert interaction.credit_transaction.present?, "esperado que se creara la CreditTransaction"

    # 7. Partida doble: el ledger de esta transacción balancea.
    tx = interaction.credit_transaction
    debits  = tx.ledger_entries.where(direction: "debit").sum(:amount)
    credits = tx.ledger_entries.where(direction: "credit").sum(:amount)
    assert_equal debits, credits, "ledger desbalanceado tras el cierre"
    assert_equal 30,     debits

    # 8. Σ global de cached_balance queda en 0.
    assert_equal 0, Account.sum(:cached_balance)

    # 9. Receiver deja review del sender.
    post post_reviews_path(@post), params: {
      review: { score: 5, comment: "Excelente comprador", interaction_id: interaction.id, category_weight: @post.category.trust_weight }
    }
    assert_redirected_to @post
    review = interaction.reviews.where(reviewer: @receiver).first
    assert review.present?
    assert_equal 5, review.score
    sign_out

    # 10. Sender también deja la suya — doble review completa.
    sign_in_as(@sender)
    post post_reviews_path(@post), params: {
      review: { score: 4, comment: "Buen vendedor", interaction_id: interaction.id, category_weight: @post.category.trust_weight }
    }
    assert_equal 2, interaction.reviews.count
  end

  test "happy path con monto cero (categoría no comercial) salta CreditTransfer pero sí cierra y permite review" do
    info_cat = Category.find_or_create_by!(name: "Información") do |c|
      c.trust_weight = 1; c.allows_credit = false; c.max_credit_multiplier = 0.2
    end
    post_zero = create_post(user: @receiver, title: "Aviso vecinal", category: info_cat)

    sign_in_as(@sender)
    post post_interactions_path(post_zero), params: { interaction: { agreed_credits: 0 } }
    interaction = Interaction.last
    sign_out

    sign_in_as(@receiver); patch accept_interaction_path(interaction); sign_out
    sign_in_as(@sender); patch start_interaction_path(interaction); patch confirm_interaction_path(interaction); sign_out
    sign_in_as(@receiver); patch confirm_interaction_path(interaction)

    interaction.reload
    assert_equal "completed", interaction.status
    assert_nil interaction.credit_transaction, "sin créditos acordados, no debe crearse CreditTransaction"
  end

  test "insufficient_balance revierte la confirmación que disparó el cierre" do
    # Receiver tiene piso 100 → puede gastar 100 yendo a deuda. Sender pide 200.
    sign_in_as(@sender)
    post post_interactions_path(@post), params: { interaction: { agreed_credits: 50 } }
    interaction = Interaction.last
    sign_out

    # Bajamos el piso del sender a 10 para forzar insufficient_balance.
    @sender.update!(credit_floor: 10)

    sign_in_as(@receiver); patch accept_interaction_path(interaction); sign_out
    sign_in_as(@sender); patch start_interaction_path(interaction); patch confirm_interaction_path(interaction); sign_out

    sign_in_as(@receiver)
    patch confirm_interaction_path(interaction)
    # Rollback: status NO debe haber pasado a completed.
    interaction.reload
    assert_equal "in_progress", interaction.status
    assert_nil interaction.receiver_completed_at, "la confirmación que disparó el intento fallido se revierte"
    assert_nil interaction.credit_transaction
  end
end
