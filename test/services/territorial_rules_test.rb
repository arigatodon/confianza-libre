require "test_helper"

# Fase 3.1 — economía territorial real: overrides de parámetros por territorio.
class TerritorialRulesTest < ActiveSupport::TestCase
  setup do
    setup_economy!
    @a = Territory.create!(name: "ComunaA", country_code: "CL", admin1: "X", admin2: "ComunaA", source: "admin")
    @b = Territory.create!(name: "ComunaB", country_code: "CL", admin1: "X", admin2: "ComunaB", source: "admin")
    @a.ensure_community_account!
    @b.ensure_community_account!
  end

  # ---- lectura override → global → default ----
  test "get resuelve override del territorio, con fallback a global" do
    set_param(:burn_percent, 2)
    assert_equal 2.0, EconomicParameter.get_decimal("burn_percent", territory: @a), "sin override cae a global"

    EconomicParameter.create!(key: "burn_percent", value: "9", territory: @a)
    EconomicParameter.reset_cache!
    assert_equal 9.0, EconomicParameter.get_decimal("burn_percent", territory: @a)
    assert_equal 2.0, EconomicParameter.get_decimal("burn_percent", territory: @b), "B no se afecta"
    assert_equal 2.0, EconomicParameter.get_decimal("burn_percent"), "el global queda intacto"
  end

  # ---- CreditTransfer usa las reglas del territorio ----
  FakeResolve = Struct.new(:territory) { def ok? = true }

  # Swap temporal de TerritoryResolver.resolve (minitest 6 no trae stub).
  def with_territory(territory)
    original = TerritoryResolver.method(:resolve)
    fake = FakeResolve.new(territory)
    TerritoryResolver.define_singleton_method(:resolve) { |*_args| fake }
    yield
  ensure
    TerritoryResolver.define_singleton_method(:resolve, original)
  end

  def completed_interaction(amount:)
    sender = create_user(username: "s#{SecureRandom.hex(2)}")
    receiver = create_user(username: "r#{SecureRandom.hex(2)}")
    post = create_post(user: receiver, category: Category.find_by(name: "Servicios"))
    i = create_interaction(post: post, sender: sender, receiver: receiver,
                           status: :in_progress, agreed_credits: amount)
    i.update!(sender_completed_at: Time.current, receiver_completed_at: Time.current, status: :completed)
    i
  end

  test "dos comunas con burn distinto queman distinto en la misma transacción" do
    set_param(:burn_percent, 2)
    EconomicParameter.create!(key: "burn_percent", value: "10", territory: @a)
    EconomicParameter.create!(key: "burn_percent", value: "4",  territory: @b)
    EconomicParameter.reset_cache!

    res_a = with_territory(@a) { CreditTransfer.call(completed_interaction(amount: 50)) }
    assert res_a.ok?, res_a.error
    assert_equal 5, res_a.credit_transaction.burn_amount  # 50 × 10%

    res_b = with_territory(@b) { CreditTransfer.call(completed_interaction(amount: 50)) }
    assert_equal 2, res_b.credit_transaction.burn_amount  # 50 × 4%
  end

  # ---- aislamiento de rule_change local ----
  def rule_change(territory:, key:, value:, global: false)
    proposer = create_user(username: "prop#{SecureRandom.hex(2)}")
    proposer.update_columns(level: 2)
    p = territory.proposals.create!(
      proposer: proposer, kind: :rule_change,
      title: "Cambiar #{key}", body: "Propuesta de cambio de regla local o global",
      parameter_key: key, parameter_value: value.to_s, parameter_global: global
    )
    p.update!(status: :passed)
    p
  end

  test "un rule_change local no toca ni a la otra comuna ni al global" do
    set_param(:territory_percent, 3)
    p = rule_change(territory: @a, key: "territory_percent", value: 8)
    result = ProposalExecutor.call(p)
    assert result.ok?
    EconomicParameter.reset_cache!

    assert_equal 8.0, EconomicParameter.get_decimal("territory_percent", territory: @a)
    assert_equal 3.0, EconomicParameter.get_decimal("territory_percent", territory: @b)
    assert_equal 3.0, EconomicParameter.get_decimal("territory_percent")
  end

  test "un rule_change global cambia el valor global" do
    set_param(:territory_percent, 3)
    p = rule_change(territory: @a, key: "territory_percent", value: 6, global: true)
    ProposalExecutor.call(p)
    EconomicParameter.reset_cache!

    assert_equal 6.0, EconomicParameter.get_decimal("territory_percent")
    assert_nil EconomicParameter.find_by(key: "territory_percent", territory: @a), "no debe crear override local"
  end

  test "el rango seguro min/max aplica también a un override local" do
    # burn_percent tope 10; 20 debe ser inválido en la propuesta.
    proposer = create_user(username: "propx")
    proposer.update_columns(level: 2)
    p = @a.proposals.new(proposer: proposer, kind: :rule_change,
                         title: "Quema abusiva", body: "Intento de subir la quema fuera de rango",
                         parameter_key: "burn_percent", parameter_value: "20")
    assert_not p.valid?
  end
end
