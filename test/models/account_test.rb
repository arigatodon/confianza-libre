require "test_helper"

class AccountTest < ActiveSupport::TestCase
  setup do
    setup_economy!
    @user = create_user(username: "acctu")
  end

  test "una cuenta user exige user y rechaza territory" do
    a = Account.new(account_type: "user", cached_balance: 0)
    refute a.valid?
    assert a.errors[:user_id].any?

    territory = Territory.create!(name: "T", country_code: "CL", admin1: "R", admin2: "C",
                                  source: "admin", latitude: -33.0, longitude: -70.0,
                                  slug: "t-#{SecureRandom.hex(3)}")
    a = Account.new(account_type: "user", user: @user, territory: territory, cached_balance: 0)
    refute a.valid?
    assert a.errors[:territory_id].any?
  end

  test "las cuentas globales (burn/system) no admiten owner" do
    a = Account.new(account_type: "burn", user: @user, cached_balance: 0)
    refute a.valid?
    assert a.errors[:user_id].any?
  end

  test "rechaza account_type desconocido" do
    a = Account.new(account_type: "cripto", cached_balance: 0)
    refute a.valid?
    assert a.errors[:account_type].any?
  end

  test "ensure_credit_account! es idempotente — una sola cuenta por usuario" do
    first = @user.ensure_credit_account!
    again = @user.ensure_credit_account!
    assert_equal first.id, again.id
    assert_equal 1, Account.where(user: @user, account_type: "user").count
  end

  test "available_balance suma el credit_floor solo en cuentas user" do
    account = @user.ensure_credit_account!
    account.update!(cached_balance: -10)
    assert_equal(-10 + @user.credit_floor, account.available_balance)

    burn = Account.find_by!(account_type: "burn")
    assert_equal burn.cached_balance, burn.available_balance
  end
end
