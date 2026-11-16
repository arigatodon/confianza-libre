class ProposalsController < ApplicationController
  before_action :set_territory, only: [ :create ]
  before_action :set_proposal,  only: [ :show, :vote, :execute, :cancel ]
  before_action :close_if_due,  only: [ :show, :vote, :execute, :cancel ]

  def show
  end

  def create
    @proposal = @territory.proposals.build(proposal_params.merge(proposer: Current.session.user))

    if @proposal.save
      redirect_to proposal_path(@proposal),
                  notice: "Propuesta creada. Ahora la comunidad puede votar."
    else
      # Re-render territories#show con el form abierto y los errores visibles,
      # preservando los datos cargados. Setup mínimo del territorio.
      render_territory_with_errors
    end
  end

  def vote
    position = params[:position].to_i
    return redirect_to(proposal_path(@proposal), alert: "Voto inválido.") unless [ -1, 1 ].include?(position)

    vote = @proposal.votes.find_or_initialize_by(user: Current.session.user)
    vote.position = position

    if vote.save
      redirect_to proposal_path(@proposal), notice: position == 1 ? "Voto a favor registrado." : "Voto en contra registrado."
    else
      redirect_to proposal_path(@proposal), alert: vote.errors.full_messages.to_sentence
    end
  end

  def execute
    unless Current.session.user_id == @proposal.proposer_id
      return redirect_to(proposal_path(@proposal), alert: "Sólo el proponente puede ejecutarla.")
    end

    result = ProposalExecutor.call(@proposal)
    if result.ok?
      redirect_to proposal_path(@proposal), notice: execution_notice
    else
      redirect_to proposal_path(@proposal), alert: "No se pudo ejecutar: #{result.error}#{" (#{result.meta[:message]})" if result.meta&.dig(:message)}"
    end
  end

  def cancel
    unless Current.session.user_id == @proposal.proposer_id && @proposal.open?
      return redirect_to(proposal_path(@proposal), alert: "No puedes cancelar esta propuesta.")
    end

    @proposal.update!(status: :canceled)
    redirect_to territory_path(@proposal.territory.slug), notice: "Propuesta cancelada."
  end

  private

  def set_territory
    @territory = Territory.friendly.find(params[:territory_slug])
  end

  def set_proposal
    @proposal = Proposal.includes(:territory, :proposer, :beneficiary, :votes).find(params[:id])
    @territory = @proposal.territory
  end

  def close_if_due
    @proposal&.close_if_due!
  end

  def proposal_params
    permitted = params.expect(proposal: [ :kind, :title, :body, :amount, :beneficiary_id,
                                          :category_name, :category_description,
                                          :parameter_key, :parameter_value, :parameter_global ])
    # Un kind desconocido haría explotar el enum en la asignación.
    permitted[:kind] = "fund_transfer" unless Proposal::KINDS.key?(permitted[:kind].to_s.to_sym)
    permitted
  end

  def execution_notice
    case @proposal.kind
    when "new_category"
      "Categoría \"#{@proposal.category_name}\" creada — ya se puede publicar en ella."
    when "rule_change"
      "Regla actualizada: #{@proposal.governable_parameter&.dig(:label)} ahora vale #{@proposal.current_parameter_value}."
    else
      "Propuesta ejecutada — #{@proposal.amount} C transferidos al fondo del beneficiario."
    end
  end

  # Render territories#show preservando @proposal con sus errores en el form.
  # El partial proposals/_form se entera vía @new_proposal y el details se
  # abre automáticamente cuando hay errores (ver views/territories/show).
  def render_territory_with_errors
    @fund = @territory.community_account
    base  = CreditTransaction.where(territory: @territory, status: :completed)
    @stats = {
      transactions:   base.count,
      total_funded:   base.sum(:community_amount),
      distinct_users: base.joins(:interaction).pluck("interactions.sender_id", "interactions.receiver_id").flatten.uniq.size,
      distinct_posts: base.joins(:interaction).distinct.count("interactions.post_id")
    }
    @recent_transactions = base.includes(interaction: [ :sender, :receiver, :post ])
                               .order(created_at: :desc).limit(20)
    @proposals = @territory.proposals.includes(:proposer, :beneficiary, :votes)
                                     .order(created_at: :desc).limit(20)
    @new_proposal = @proposal
    local_keys = EconomicParameter.where(territory: @territory).pluck(:key).to_set
    @rules = Proposal::GOVERNABLE_PARAMETERS.map do |key, rule|
      { label: rule[:label], value: EconomicParameter.get(key, territory: @territory), local: local_keys.include?(key) }
    end
    flash.now[:alert] = @proposal.errors.full_messages.to_sentence
    render "territories/show", status: :unprocessable_entity
  end
end
