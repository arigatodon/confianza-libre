class TerritoriesController < ApplicationController
  allow_unauthenticated_access only: [ :index, :show ]
  before_action :set_territory, only: :show

  def index
    @territories = Territory
                     .includes(:community_account)
                     .order(Arel.sql("COALESCE((SELECT cached_balance FROM accounts WHERE accounts.territory_id = territories.id LIMIT 1), 0) DESC, territories.name ASC"))
  end

  def show
    @fund = @territory.community_account
    base = CreditTransaction.where(territory: @territory, status: :completed)

    @stats = {
      transactions:  base.count,
      total_funded:  base.sum(:community_amount),
      distinct_users: distinct_user_count(base),
      distinct_posts: base.joins(:interaction).distinct.count("interactions.post_id")
    }

    @recent_transactions = base
                            .includes(interaction: [ :sender, :receiver, :post ])
                            .order(created_at: :desc)
                            .limit(20)

    @proposals = @territory.proposals
                            .includes(:proposer, :beneficiary, :votes)
                            .order(created_at: :desc)
                            .limit(20)
    # Cerramos lazy las que vencieron sin voto.
    @proposals.each(&:close_if_due!)

    @new_proposal = Proposal.new if authenticated?

    # Reglas económicas: cuáles rigen localmente (override) vs heredadas del
    # global (Fase 3.1). Solo mostramos las gobernables por propuesta.
    local_keys = EconomicParameter.where(territory: @territory).pluck(:key).to_set
    @rules = Proposal::GOVERNABLE_PARAMETERS.map do |key, rule|
      {
        label: rule[:label],
        value: EconomicParameter.get(key, territory: @territory),
        local: local_keys.include?(key)
      }
    end
  end

  private

  def set_territory
    @territory = Territory.friendly.find(params[:slug])
  end

  def distinct_user_count(scope)
    user_ids = scope.joins(:interaction).pluck("interactions.sender_id", "interactions.receiver_id").flatten.uniq
    user_ids.size
  end
end
