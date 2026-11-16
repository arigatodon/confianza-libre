require "test_helper"

class ProposalTest < ActiveSupport::TestCase
  setup do
    setup_economy!
    @territory = Territory.create!(name: "TestComuna", country_code: "CL", admin1: "X", admin2: "TestComuna", source: "admin")
    @territory.ensure_community_account!
    @proposer    = create_user(username: "proposerp")
    @beneficiary = create_user(username: "benefp")
  end

  def build_proposal(**attrs)
    @territory.proposals.build({
      proposer: @proposer, beneficiary: @beneficiary,
      title: "Pintura mural", body: "Para la plaza",
      amount: 50
    }.merge(attrs))
  end

  test "rechaza si proposer == beneficiary" do
    p = build_proposal(beneficiary: @proposer)
    refute p.valid?
    assert_match /no puedes proponerte/, p.errors.full_messages.to_sentence
  end

  test "voto del proposer está bloqueado" do
    p = build_proposal; p.save!
    vote = p.votes.build(user: @proposer, position: 1)
    refute vote.valid?
    assert_match /proponente no vota/i, vote.errors.full_messages.to_sentence
  end

  test "uniqueness: un usuario no puede votar dos veces la misma propuesta" do
    p = build_proposal; p.save!
    voter = create_user(username: "voterx")
    p.votes.create!(user: voter, position: 1)
    second = p.votes.build(user: voter, position: -1)
    refute second.valid?
    assert_match /ya votaste/, second.errors.full_messages.to_sentence
  end

  test "close_if_due! → passed cuando quórum + mayoría cumplidos y se venció el plazo" do
    p = build_proposal; p.save!
    2.times { |n|
      voter = create_user(username: "yp#{n}")
      p.votes.create!(user: voter, position: 1)
    }
    p.update_column(:voting_closes_at, 1.minute.ago)
    p.close_if_due!
    assert_equal "passed", p.reload.status
  end

  test "close_if_due! → failed si no llega a quórum aunque sea unánime" do
    p = build_proposal; p.save!
    voter = create_user(username: "lone")
    p.votes.create!(user: voter, position: 1)  # sólo 1 voto, quórum 2
    p.update_column(:voting_closes_at, 1.minute.ago)
    p.close_if_due!
    assert_equal "failed", p.reload.status
  end
end
