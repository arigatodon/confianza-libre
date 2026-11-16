class ProposalVote < ApplicationRecord
  POSITIONS = { against: -1, in_favor: 1 }.freeze

  belongs_to :proposal
  belongs_to :user

  validates :position, inclusion: { in: POSITIONS.values }
  validates :user_id, uniqueness: { scope: :proposal_id, message: "ya votaste en esta propuesta" }
  validate  :proposal_is_open
  validate  :user_is_not_proposer

  def in_favor?; position ==  1; end
  def against?;  position == -1; end

  private

  def proposal_is_open
    return unless proposal
    errors.add(:proposal, "no acepta votos en este estado") unless proposal.open? && !proposal.voting_closed?
  end

  def user_is_not_proposer
    return unless proposal && user_id == proposal.proposer_id
    errors.add(:user, "el proponente no vota su propia propuesta")
  end
end
