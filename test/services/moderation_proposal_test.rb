require "test_helper"

# Fase 1.3 — rol de moderador desacoplado del nivel + gobernanza grant/revoke.
class ModerationProposalTest < ActiveSupport::TestCase
  setup do
    setup_economy!
    @territory = Territory.create!(name: "ModComuna", country_code: "CL",
                                   admin1: "Test", admin2: "ModComuna", source: "admin")
    # Proponente con nivel para proponer cambios estructurales.
    @proposer = create_user(username: "proponente")
    @proposer.update_columns(level: 2)
    @target = create_user(username: "candidato")
  end

  # ---- decoupling ----
  test "moderator? depende del flag, no del nivel económico" do
    subelevel = create_user(username: "ricachon")
    subelevel.update_columns(level: 5) # nivel máximo pero sin flag
    assert_not subelevel.moderator?, "subir de nivel no debe otorgar moderación"

    humilde = create_user(username: "humilde")
    humilde.update_columns(level: 1)
    humilde.grant_moderation!
    assert humilde.moderator?, "el flag otorga moderación sin importar el nivel"
  end

  # ---- grant ----
  def moderation_proposal(kind:, beneficiary:)
    p = @territory.proposals.create!(
      proposer: @proposer, beneficiary: beneficiary, kind: kind,
      title: "Moderación para @#{beneficiary.username}", body: "Propuesta de moderación de la comunidad"
    )
    p.update!(status: :passed)
    p
  end

  test "grant_moderation aprobada otorga el rol y notifica" do
    p = moderation_proposal(kind: :grant_moderation, beneficiary: @target)
    result = ProposalExecutor.call(p)
    assert result.ok?
    assert @target.reload.moderator?
    assert p.reload.executed?
    assert @target.notifications.where(kind: "moderation_role").exists?
  end

  test "revoke_moderation aprobada quita el rol" do
    @target.grant_moderation!
    p = moderation_proposal(kind: :revoke_moderation, beneficiary: @target)
    result = ProposalExecutor.call(p)
    assert result.ok?
    assert_not @target.reload.moderator?
  end

  # ---- validaciones ----
  test "no se puede proponer nombrarse a uno mismo" do
    p = @territory.proposals.new(proposer: @proposer, beneficiary: @proposer,
                                 kind: :grant_moderation, title: "Yo mismo", body: "Me nombro moderador porfa")
    assert_not p.valid?
  end

  test "no se puede nombrar a quien ya es moderador" do
    @target.grant_moderation!
    p = @territory.proposals.new(proposer: @proposer, beneficiary: @target,
                                 kind: :grant_moderation, title: "Otra vez", body: "Nombrar de nuevo al mod")
    assert_not p.valid?
  end

  test "no se puede revocar a quien no es moderador" do
    p = @territory.proposals.new(proposer: @proposer, beneficiary: @target,
                                 kind: :revoke_moderation, title: "Revocar", body: "Quitar rol a quien no lo tiene")
    assert_not p.valid?
  end

  test "nombrar moderación exige el nivel de propuestas estructurales" do
    novato = create_user(username: "novato") # nivel 1 por default
    p = @territory.proposals.new(proposer: novato, beneficiary: @target,
                                 kind: :grant_moderation, title: "Sin nivel", body: "Propuesta sin nivel suficiente")
    assert_not p.valid?
  end
end
