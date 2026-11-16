require "test_helper"

class ProposalExecutorTest < ActiveSupport::TestCase
  setup do
    setup_economy!
    @territory = Territory.create!(name: "TestComuna", country_code: "CL", admin1: "Test", admin2: "TestComuna", source: "admin")
    @territory.ensure_community_account!
    @proposer    = create_user(username: "proposer")
    @beneficiary = create_user(username: "benef")
  end

  def open_proposal(amount:, voted_yes: 0, voted_no: 0)
    p = @territory.proposals.create!(
      proposer: @proposer, beneficiary: @beneficiary,
      title: "Pago al barrio", body: "Detalle del gasto",
      amount: amount
    )
    voted_yes.times { |n|
      voter = create_user(username: "yes#{n}")
      p.votes.create!(user: voter, position: 1)
    }
    voted_no.times { |n|
      voter = create_user(username: "no#{n}")
      p.votes.create!(user: voter, position: -1)
    }
    p
  end

  test "rechaza not_passed si la propuesta sigue open" do
    p = open_proposal(amount: 50, voted_yes: 2)
    result = ProposalExecutor.call(p)
    refute result.ok?
    assert_equal :not_passed, result.error
  end

  test "rechaza insufficient_fund si la cuenta community no tiene saldo" do
    p = open_proposal(amount: 50, voted_yes: 2)
    p.update!(status: :passed)  # forzar transición sin pasar por close_if_due
    result = ProposalExecutor.call(p)
    refute result.ok?
    assert_equal :insufficient_fund, result.error
  end

  test "happy path: transfiere amount del community al beneficiary y marca executed" do
    # Cargar el fondo manualmente.
    @territory.community_account.update!(cached_balance: 200)
    p = open_proposal(amount: 80, voted_yes: 2)
    p.update!(status: :passed)

    result = ProposalExecutor.call(p)
    assert result.ok?, "esperado ok, error=#{result.error}"

    assert_equal 120, @territory.community_account.reload.cached_balance  # 200 − 80
    assert_equal 80,  @beneficiary.credit_account.reload.cached_balance
    assert_equal "executed", p.reload.status
    assert p.execution_credit_transaction.present?
  end

  test "ledger entries balancean (debit == credit) en la transferencia ejecutada" do
    @territory.community_account.update!(cached_balance: 50)
    p = open_proposal(amount: 50, voted_yes: 2)
    p.update!(status: :passed)

    result = ProposalExecutor.call(p)
    tx = result.credit_transaction
    debits  = tx.ledger_entries.where(direction: "debit").sum(:amount)
    credits = tx.ledger_entries.where(direction: "credit").sum(:amount)
    assert_equal debits, credits, "ledger desbalanceado: debits=#{debits}, credits=#{credits}"
    assert_equal 50, debits
  end
end
