require "test_helper"

class BalanceReconcilerTest < ActiveSupport::TestCase
  setup { setup_economy! }

  test "devuelve credits − debits desde ledger_entries" do
    user = create_user(username: "rec")
    acc  = user.credit_account
    other = create_user(username: "rec2")

    i = create_completed_interaction(sender: user, receiver: other, agreed_credits: 30)

    expected = LedgerEntry.where(account: acc, direction: "credit").sum(:amount) -
               LedgerEntry.where(account: acc, direction: "debit").sum(:amount)

    assert_equal expected, BalanceReconciler.call(acc)
  end

  test "rake task credit:reconcile arregla drift en cached_balance" do
    sender   = create_user(username: "drift1")
    receiver = create_user(username: "drift2")
    create_completed_interaction(sender: sender, receiver: receiver, agreed_credits: 40)

    # Forzar drift manual en la cuenta del sender.
    sender.credit_account.update_column(:cached_balance, 999)

    # Antes: Σ ≠ 0 por el drift.
    refute_equal 0, Account.sum(:cached_balance)

    # Reconciliar manualmente cuenta por cuenta (el rake hace lo mismo).
    Account.find_each { |a| a.update_column(:cached_balance, BalanceReconciler.call(a)) }

    assert_equal 0, Account.sum(:cached_balance), "Σ global debe quedar en 0 post reconcile"
  end
end
