require "test_helper"

class LedgerEntryTest < ActiveSupport::TestCase
  setup do
    setup_economy!
    @sender   = create_user(username: "ledsdr")
    @receiver = create_user(username: "ledrcv")
  end

  test "rechaza montos cero o negativos y direcciones inválidas" do
    i  = create_completed_interaction(sender: @sender, receiver: @receiver, agreed_credits: 20)
    tx = i.credit_transaction

    entry = tx.ledger_entries.new(account: @sender.credit_account, direction: "debit", amount: 0)
    refute entry.valid?
    assert entry.errors[:amount].any?

    entry.amount = 5
    entry.direction = "transfer"
    refute entry.valid?
    assert entry.errors[:direction].any?
  end

  test "una transferencia real deja el ledger balanceado (Σ debits = Σ credits)" do
    i  = create_completed_interaction(sender: @sender, receiver: @receiver, agreed_credits: 40)
    tx = i.credit_transaction

    debits  = tx.ledger_entries.where(direction: "debit").sum(:amount)
    credits = tx.ledger_entries.where(direction: "credit").sum(:amount)
    assert_equal debits, credits
    assert_equal 40, debits
  end

  test "ledger_must_balance rechaza completar una transacción desbalanceada" do
    i  = create_completed_interaction(sender: @sender, receiver: @receiver, agreed_credits: 20)
    tx = i.credit_transaction

    tx.ledger_entries.create!(account: @receiver.credit_account, direction: "credit", amount: 7)
    refute tx.valid?
    assert_match /desbalanceado/, tx.errors.full_messages.to_sentence
  end

  test "los cached_balance del sistema completo suman cero" do
    create_completed_interaction(sender: @sender, receiver: @receiver, agreed_credits: 30)
    assert_equal 0, Account.sum(:cached_balance),
      "partida doble: lo que sale de una cuenta entra en otras"
  end
end
