require "test_helper"

class GobernanzaTest < ActionDispatch::IntegrationTest
  setup do
    setup_economy!
    @territorio = Territory.create!(name: "Comuna Gobernanza", country_code: "CL")
    @proponente = create_user(username: "proponente")
    @proponente.update_columns(level: 2)
    @votante1 = create_user(username: "votante1")
    @votante2 = create_user(username: "votante2")
  end

  # Vota a favor con los dos votantes (quorum de test = 2), vence el plazo
  # y cierra la propuesta — queda :passed.
  def aprobar!(proposal)
    [ @votante1, @votante2 ].each { |v| proposal.votes.create!(user: v, position: 1) }
    proposal.update!(voting_closes_at: 1.minute.ago)
    proposal.close_if_due!
    assert proposal.passed?, "la propuesta debería haber pasado (#{proposal.status})"
  end

  test "cambio de regla aprobado actualiza el parámetro económico al ejecutarse" do
    sign_in_as @proponente
    post territory_proposals_path(@territorio.slug), params: { proposal: {
      kind: "rule_change",
      title: "Subir la quema al 3%",
      body:  "Más quema por transacción para cuidar el valor del crédito.",
      parameter_key: "burn_percent", parameter_value: "3", parameter_global: "1"
    } }
    proposal = Proposal.order(:id).last
    assert_redirected_to proposal_path(proposal)
    assert proposal.rule_change?

    aprobar!(proposal)
    assert_equal "2", EconomicParameter.get("burn_percent")

    patch execute_proposal_path(proposal)
    assert_redirected_to proposal_path(proposal)
    assert proposal.reload.executed?
    assert_equal "3", EconomicParameter.get("burn_percent")
  end

  test "propuesta de categoría aprobada crea la categoría al ejecutarse" do
    sign_in_as @proponente
    post territory_proposals_path(@territorio.slug), params: { proposal: {
      kind: "new_category",
      title: "Categoría Huerta urbana",
      body:  "Para intercambiar semillas, plantines y saberes de cultivo.",
      category_name: "Huerta urbana"
    } }
    proposal = Proposal.order(:id).last
    assert proposal.new_category?

    aprobar!(proposal)
    assert_nil Category.find_by(name: "Huerta urbana")

    patch execute_proposal_path(proposal)
    categoria = Category.find_by(name: "Huerta urbana")
    assert categoria.present?
    assert categoria.publishable?
    assert_not categoria.allows_credit?
    assert proposal.reload.executed?
  end

  test "usuario nivel 1 no puede proponer cambios de reglas" do
    novato = create_user(username: "novato")
    sign_in_as novato
    assert_no_difference "Proposal.count" do
      post territory_proposals_path(@territorio.slug), params: { proposal: {
        kind: "rule_change",
        title: "Quema al 10% ya",
        body:  "Sin participación previa quiero cambiar las reglas.",
        parameter_key: "burn_percent", parameter_value: "10"
      } }
    end
    assert_response :unprocessable_entity
    assert_match(/nivel 2/, response.body)
  end

  test "valor fuera del rango seguro o parámetro no gobernable se rechazan" do
    sign_in_as @proponente
    assert_no_difference "Proposal.count" do
      post territory_proposals_path(@territorio.slug), params: { proposal: {
        kind: "rule_change", title: "Quema al 90%",
        body: "Valor absurdo que debe rebotar.",
        parameter_key: "burn_percent", parameter_value: "90"
      } }
      post territory_proposals_path(@territorio.slug), params: { proposal: {
        kind: "rule_change", title: "Tocar países permitidos",
        body: "Parámetro sensible fuera de la lista blanca.",
        parameter_key: "allowed_countries", parameter_value: "1"
      } }
    end
  end

  test "categoría duplicada se rechaza" do
    sign_in_as @proponente
    assert_no_difference "Proposal.count" do
      post territory_proposals_path(@territorio.slug), params: { proposal: {
        kind: "new_category", title: "Categoría Servicios bis",
        body: "Ya existe una categoría con este nombre.",
        category_name: "servicios"
      } }
    end
    assert_match(/ya existe/, response.body)
  end

  test "propuesta de fondo sigue exigiendo beneficiario y monto" do
    sign_in_as @proponente
    assert_no_difference "Proposal.count" do
      post territory_proposals_path(@territorio.slug), params: { proposal: {
        kind: "fund_transfer", title: "Créditos sin destino",
        body: "Falta el beneficiario, debe rebotar."
      } }
    end
  end

  test "el quórum de reglas escala con los miembros activos de la red" do
    set_param("rules_quorum_percent", 50)
    propuesta = @territorio.proposals.create!(
      kind: "rule_change", proposer: @proponente,
      title: "Quórum escalado", body: "El quórum debe crecer con la red.",
      parameter_key: "proposal_voting_days", parameter_value: "5"
    )
    # 3 usuarios activos del setup → 50% = 2, igual al quórum base (2).
    assert_equal 2, propuesta.quorum_required

    6.times { |i| create_user(username: "extra#{i}") }
    # 9 activos → ceil(50%) = 5 supera la base.
    assert_equal 5, propuesta.quorum_required

    # Las propuestas de fondo mantienen el quórum base.
    fondo = @territorio.proposals.create!(
      kind: "fund_transfer", proposer: @proponente, beneficiary: @votante1,
      amount: 10, title: "Fondo con quórum base", body: "El fondo no escala el quórum."
    )
    assert_equal 2, fondo.quorum_required
  end

  test "el umbral territorial bloquea proponer reglas en territorios chicos" do
    set_param("territory_min_members_for_rules", 3)
    propuesta = @territorio.proposals.build(
      kind: "rule_change", proposer: @proponente,
      title: "Sin miembros suficientes", body: "El territorio recién arranca.",
      parameter_key: "proposal_voting_days", parameter_value: "5"
    )
    assert_not propuesta.valid?
    assert_match(/miembros activos/, propuesta.errors.full_messages.to_sentence)
  ensure
    set_param("territory_min_members_for_rules", 0)
  end

  test "logros de democracia se desbloquean al votar y al ser aprobada una propuesta" do
    proposal = @territorio.proposals.create!(
      kind: "rule_change", proposer: @proponente,
      title: "Votación de prueba", body: "Para destrabar logros democráticos.",
      parameter_key: "proposal_voting_days", parameter_value: "5"
    )

    badges = AchievementCatalog.new(@votante1).badges.index_by(&:key)
    assert_not badges["first_vote"].unlocked

    proposal.votes.create!(user: @votante1, position: 1)
    badges = AchievementCatalog.new(@votante1.reload).badges.index_by(&:key)
    assert badges["first_vote"].unlocked

    badges = AchievementCatalog.new(@proponente).badges.index_by(&:key)
    assert badges["proposer"].unlocked
    assert_not badges["reformer"].unlocked

    proposal.votes.create!(user: @votante2, position: 1)
    proposal.update!(voting_closes_at: 1.minute.ago)
    proposal.close_if_due!
    badges = AchievementCatalog.new(@proponente).badges.index_by(&:key)
    assert badges["reformer"].unlocked
  end
end
