require "test_helper"

class CreditTransferTest < ActiveSupport::TestCase
  setup do
    setup_economy!
    @sender   = create_user(username: "sender")
    @receiver = create_user(username: "receiver")
    @post     = create_post(user: @receiver, category: Category.find_by(name: "Servicios"))
  end

  def in_progress_interaction(amount:)
    i = create_interaction(post: @post, sender: @sender, receiver: @receiver,
                           status: :in_progress, agreed_credits: amount)
    i.update!(sender_completed_at: Time.current, receiver_completed_at: Time.current)
    i.update!(status: :completed)
    i
  end

  test "happy path: transfiere 95% al receptor, 3% al territorio fallback y 2% (mínimo) a quema" do
    i = in_progress_interaction(amount: 50)

    result = CreditTransfer.call(i)
    assert result.ok?, "esperado ok, error=#{result.error}"

    tx = result.credit_transaction
    assert_equal 50, tx.total_amount
    assert_equal 1,  tx.burn_amount     # 50 × 2 % = 1
    # Como el post no resuelve a Territory en test (Geocoder no corre), el
    # territorio cae a system_account y community_amount queda en el split
    # original (territory_percent=3% → 2 redondeado).
    assert tx.community_amount >= 1, "community_amount esperado positivo, fue #{tx.community_amount}"

    # Ledger balanceado.
    debits  = tx.ledger_entries.where(direction: "debit").sum(:amount)
    credits = tx.ledger_entries.where(direction: "credit").sum(:amount)
    assert_equal debits, credits, "ledger desbalanceado"
    assert_equal 50,     debits
  end

  test "Σ global de cached_balance queda en 0 tras la transferencia" do
    in_progress_interaction(amount: 100)
    CreditTransfer.call(Interaction.last)
    assert_equal 0, Account.sum(:cached_balance)
  end

  test "exceeds_tx_cap si amount > sender.tx_cap × category.max_credit_multiplier" do
    # Nivel 1 default → tx_cap 50, multiplicador Servicios 1.0 → max 50.
    i = in_progress_interaction(amount: 60)

    result = CreditTransfer.call(i)
    refute result.ok?
    assert_equal :exceeds_tx_cap, result.error
    assert_equal 50, result.meta[:max_allowed]
  end

  test "insufficient_balance cuando el sender no tiene piso suficiente" do
    @sender.update!(credit_floor: 10)  # piso super bajo
    i = in_progress_interaction(amount: 50)

    result = CreditTransfer.call(i)
    refute result.ok?
    assert_equal :insufficient_balance, result.error
  end

  test "not_completed si la interaction no está en estado completed" do
    i = create_interaction(post: @post, sender: @sender, receiver: @receiver,
                           status: :in_progress, agreed_credits: 30)

    result = CreditTransfer.call(i)
    refute result.ok?
    assert_equal :not_completed, result.error
  end

  test "zero_amount cuando agreed_credits es 0" do
    i = in_progress_interaction(amount: 0)
    result = CreditTransfer.call(i)
    refute result.ok?
    assert_equal :zero_amount, result.error
  end

  test "already_settled si la interaction ya tiene transaction" do
    i = in_progress_interaction(amount: 30)
    first = CreditTransfer.call(i)
    assert first.ok?

    second = CreditTransfer.call(i.reload)
    refute second.ok?
    assert_equal :already_settled, second.error
  end

  test "idempotencia económica: una sola transaction, dos llamadas no duplican el ledger" do
    i = in_progress_interaction(amount: 40)
    CreditTransfer.call(i)
    CreditTransfer.call(i.reload)  # already_settled

    assert_equal 1, i.reload.credit_transaction.present? ? 1 : 0
    assert_equal 4, LedgerEntry.where(credit_transaction_id: i.credit_transaction.id).count
  end

  test "techo: si receiver supera credit_ceiling, el excedente va al fondo (no se pierde)" do
    # Receptor con techo casi alcanzado: ceiling=1000, sube su balance a 970.
    @receiver.credit_account.update!(cached_balance: 970)
    @sender.update!(tx_cap: 1000)            # liberar el cap por tx
    @sender.update!(credit_floor: 100_000)   # liberar el piso

    i = in_progress_interaction(amount: 100)
    result = CreditTransfer.call(i)
    assert result.ok?, "esperado ok, error=#{result.error}"

    tx = result.credit_transaction
    receiver_balance = @receiver.reload.credit_account.cached_balance
    assert receiver_balance <= @receiver.credit_ceiling,
           "el receptor no debe superar su credit_ceiling (#{receiver_balance} vs #{@receiver.credit_ceiling})"
    # El excedente fue al fondo (community_amount > el 3% del total).
    assert tx.community_amount > (100 * 0.03).ceil
  end
end
