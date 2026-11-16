require "test_helper"

class ReconcileBalancesJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    setup_economy!
    @sender   = create_user(username: "recsdr")
    @receiver = create_user(username: "recrcv")
    create_completed_interaction(sender: @sender, receiver: @receiver, agreed_credits: 30)
  end

  test "sin drift no corrige nada ni manda alerta" do
    assert_no_enqueued_emails do
      assert_equal 0, ReconcileBalancesJob.perform_now
    end
  end

  test "con drift corrige desde el ledger y alerta por email" do
    account = @receiver.credit_account
    ledger_value = account.cached_balance
    account.update_column(:cached_balance, ledger_value + 999)  # drift manual

    drifted = nil
    assert_enqueued_emails 1 do
      drifted = ReconcileBalancesJob.perform_now
    end

    assert_equal 1, drifted
    assert_equal ledger_value, account.reload.cached_balance,
      "el ledger es la fuente de verdad: el cached vuelve a calzar"
  end
end
