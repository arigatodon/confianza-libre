require "test_helper"

class ReportResolverTest < ActiveSupport::TestCase
  setup do
    setup_economy!

    @reporter  = create_user(username: "reporter1")
    @author    = create_user(username: "author1")
    @moderator = create_user(username: "mod1")
    @moderator.grant_moderation!

    @post = create_post(user: @author, title: "Algo cuestionable",
                        latitude: -33.45, longitude: -70.65)

    @report = Report.create!(reporter: @reporter, reportable: @post, reason: :spam)
  end

  test "hide oculta el post y paga reward si hay fondo territorial" do
    territory = funded_territory(amount: 100)
    with_resolver_stub(territory) do
      result = ReportResolver.call(report: @report, moderator: @moderator, action: :hide)

      assert result.ok?
      assert @report.reload.hidden?
      assert @post.reload.hidden_at.present?
      assert_equal 2, result.reward_amount
      assert_equal 2, @moderator.credit_account.reload.cached_balance
      assert_equal 98, territory.community_account.reload.cached_balance
      assert_equal territory.id, @report.territory_id
    end
  end

  test "warn no oculta y paga reward" do
    territory = funded_territory(amount: 50)
    with_resolver_stub(territory) do
      result = ReportResolver.call(report: @report, moderator: @moderator, action: :warn)

      assert result.ok?
      assert @report.reload.warned?
      assert_nil @post.reload.hidden_at
      assert_equal 2, result.reward_amount
    end
  end

  test "dismiss no paga reward" do
    territory = funded_territory(amount: 50)
    with_resolver_stub(territory) do
      result = ReportResolver.call(report: @report, moderator: @moderator, action: :dismiss)

      assert result.ok?
      assert @report.reload.dismissed?
      assert_equal 0, result.reward_amount
      assert_equal 0, @moderator.credit_account.reload.cached_balance
    end
  end

  test "resuelve sin reward cuando el fondo no alcanza" do
    territory = funded_territory(amount: 0)
    with_resolver_stub(territory) do
      result = ReportResolver.call(report: @report, moderator: @moderator, action: :hide)

      assert result.ok?
      assert @report.reload.hidden?
      assert_equal 0, result.reward_amount
    end
  end

  test "rechaza si quien resuelve no es moderador" do
    @moderator.revoke_moderation!
    result = ReportResolver.call(report: @report, moderator: @moderator, action: :hide)

    assert_not result.ok?
    assert_equal :unauthorized, result.error
    assert @report.reload.open?
  end

  test "rechaza si el moderador es el autor del contenido" do
    @post.update!(user: @moderator)
    result = ReportResolver.call(report: @report, moderator: @moderator, action: :hide)
    assert_equal :cannot_moderate_self, result.error
  end

  test "rechaza si el moderador es el reporter" do
    @report.update!(reporter: @moderator)
    result = ReportResolver.call(report: @report, moderator: @moderator, action: :hide)
    assert_equal :cannot_moderate_own_report, result.error
  end

  test "suspend requiere reportable User" do
    result = ReportResolver.call(report: @report, moderator: @moderator, action: :suspend)
    assert_equal :suspend_requires_user, result.error
  end

  test "suspend marca el usuario como suspended y paga reward" do
    user_report = Report.create!(reporter: @reporter, reportable: @author, reason: :abuse)
    @author.update!(latitude: -33.45, longitude: -70.65)
    territory = funded_territory(amount: 50)

    with_resolver_stub(territory) do
      result = ReportResolver.call(report: user_report, moderator: @moderator, action: :suspend)
      assert result.ok?
      assert @author.reload.suspended?
      assert_equal 2, result.reward_amount
    end
  end

  test "no se puede resolver un reporte ya resuelto" do
    ReportResolver.call(report: @report, moderator: @moderator, action: :dismiss)
    result = ReportResolver.call(report: @report.reload, moderator: @moderator, action: :hide)
    assert_equal :not_open, result.error
  end

  test "reportar un DirectMessage paga reward y notifica al autor (fix D9)" do
    @author.update!(latitude: -33.45, longitude: -70.65)
    conversation = Conversation.create!(participant_a: @author, participant_b: @reporter)
    dm = conversation.direct_messages.create!(user: @author, body: "spam spam spam")
    dm_report = Report.create!(reporter: @reporter, reportable: dm, reason: :spam)

    territory = funded_territory(amount: 50)
    with_resolver_stub(territory) do
      result = ReportResolver.call(report: dm_report, moderator: @moderator, action: :hide)

      assert result.ok?
      assert dm.reload.hidden_at.present?
      assert_equal 2, result.reward_amount, "el reward de un DM reportado debe pagarse"
    end

    # La notificación al autor tiene que resolver un link (fix Notification#link_path).
    notif = Notification.where(notifiable: dm_report).last
    assert notif.present?, "el autor debe recibir la notificación de moderación"
    assert_equal "/mensajes/#{conversation.id}", notif.link_path
  end

  private

  # Crea Territory + community_account sin pegarle a Geocoder, y le mete saldo
  # via debit al system_account (que no tiene piso).
  def funded_territory(amount:)
    t = Territory.create!(
      name:         "Santiago Test",
      country_code: "CL",
      admin1:       "Región Metropolitana",
      admin2:       "Santiago",
      source:       "admin",
      latitude:     -33.45,
      longitude:    -70.65,
      slug:         "santiago-test-#{SecureRandom.hex(3)}"
    )
    fund   = t.ensure_community_account!
    system = Account.find_by!(account_type: "system")
    if amount.positive?
      fund.update!(cached_balance:  fund.cached_balance + amount)
      system.update!(cached_balance: system.cached_balance - amount)
    end
    t
  end

  # Stub TerritoryResolver.resolve para que devuelva el territorio dado,
  # evitando la dependencia con Geocoder/Nominatim (flaky en CI).
  def with_resolver_stub(territory)
    fake = TerritoryResolver::Result.new(territory: territory)
    original = TerritoryResolver.method(:resolve)
    TerritoryResolver.define_singleton_method(:resolve) { |_lat, _lng| fake }
    yield
  ensure
    TerritoryResolver.singleton_class.send(:remove_method, :resolve)
    TerritoryResolver.define_singleton_method(:resolve, original) if original
  end
end
