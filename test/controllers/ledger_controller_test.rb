require "test_helper"

class LedgerControllerTest < ActionDispatch::IntegrationTest
  setup { setup_economy! }

  test "GET /ledger/audit es público y devuelve 200" do
    get ledger_audit_path
    assert_response :success
  end

  test "muestra 'Partida doble sana' cuando Σ cached_balance = 0" do
    Rails.cache.delete("ledger_audit")
    get ledger_audit_path
    assert_select "h2", /Partida doble sana/i
  end

  test "tras una transferencia real, sigue mostrando partida doble sana" do
    sender   = create_user(username: "lsdr")
    receiver = create_user(username: "lrcv")
    create_completed_interaction(sender: sender, receiver: receiver, agreed_credits: 50)

    Rails.cache.delete("ledger_audit")
    get ledger_audit_path
    assert_response :success
    assert_select "h2", /Partida doble sana/i
  end

  test "detecta y reporta 'Partida doble rota' si se introduce drift manual" do
    sender   = create_user(username: "ldsr")
    receiver = create_user(username: "ldrv")
    create_completed_interaction(sender: sender, receiver: receiver, agreed_credits: 30)

    # Romper a mano: agregar créditos a una cuenta sin contrapartida en el ledger.
    receiver.credit_account.update_column(:cached_balance, receiver.credit_account.cached_balance + 999)

    Rails.cache.delete("ledger_audit")
    get ledger_audit_path
    assert_select "h2", /Partida doble rota/i
  end
end
