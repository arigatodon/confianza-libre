class ProposalExecutor
  # Ejecuta una propuesta aprobada según su kind:
  #
  #   fund_transfer — transfiere proposal.amount desde el fondo comunitario del
  #     territorio al beneficiario, en una sola DB transaction. Crea una
  #     CreditTransaction (source = proposal) y 2 LedgerEntries: debit en la
  #     cuenta community, credit en la cuenta del beneficiario. No hay quema ni
  #     split territorial — el gasto del fondo es íntegro al beneficiario
  #     (ya pasó por el voto comunitario).
  #
  #   new_category — crea la Category votada (publishable, sin crédito por
  #     defecto: habilitar crédito en una categoría es decisión aparte).
  #
  #   rule_change — actualiza el EconomicParameter votado. El modelo ya validó
  #     que el parámetro es gobernable y el valor está dentro del rango seguro.

  Result = Struct.new(:credit_transaction, :category, :parameter, :error, :meta, keyword_init: true) do
    def ok? = error.nil?
  end

  def self.call(proposal)
    new(proposal).call
  end

  def initialize(proposal)
    @proposal = proposal
  end

  def call
    return fail(:not_passed) unless @proposal.passed?

    case @proposal.kind
    when "fund_transfer"     then execute_fund_transfer
    when "new_category"      then execute_new_category
    when "rule_change"       then execute_rule_change
    when "grant_moderation"  then execute_moderation_change(grant: true)
    when "revoke_moderation" then execute_moderation_change(grant: false)
    else fail(:unknown_kind)
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn("[ProposalExecutor] #{e.message}")
    Result.new(error: :persistence_error, meta: { message: e.message })
  end

  private

  def execute_fund_transfer
    return fail(:insufficient_fund) unless @proposal.fund_has_enough?

    fund_acc        = @proposal.fund_account
    beneficiary_acc = @proposal.beneficiary_account

    credit_tx = nil
    ActiveRecord::Base.transaction do
      credit_tx = CreditTransaction.create!(
        source:           @proposal,
        territory:        @proposal.territory,
        total_amount:     @proposal.amount,
        burn_amount:      0,
        community_amount: 0,
        status:           :pending
      )

      credit_tx.ledger_entries.create!(account: fund_acc,        direction: "debit",  amount: @proposal.amount)
      credit_tx.ledger_entries.create!(account: beneficiary_acc, direction: "credit", amount: @proposal.amount)

      credit_tx.update!(status: :completed)

      fund_acc.update!(cached_balance:        fund_acc.cached_balance - @proposal.amount)
      beneficiary_acc.update!(cached_balance: beneficiary_acc.cached_balance + @proposal.amount)

      @proposal.update!(status: :executed, execution_credit_transaction: credit_tx)
    end

    Result.new(credit_transaction: credit_tx)
  end

  def execute_new_category
    category = nil
    ActiveRecord::Base.transaction do
      category = Category.create!(
        name:        @proposal.category_name.to_s.strip,
        publishable: true
      )
      @proposal.update!(status: :executed)
    end

    Result.new(category: category)
  end

  def execute_rule_change
    rule = @proposal.governable_parameter
    return fail(:not_governable) if rule.nil?

    # Alcance: override del territorio de la propuesta, o global si se marcó.
    territory = @proposal.override_territory

    parameter = nil
    ActiveRecord::Base.transaction do
      parameter = EconomicParameter.find_or_initialize_by(key: @proposal.parameter_key.to_s, territory: territory)
      parameter.value         = normalized_value
      scope_label             = territory ? "en #{territory.name}" : "global"
      parameter.description ||= "#{rule[:label]} (#{scope_label}) — fijado por propuesta comunitaria."
      parameter.save!
      @proposal.update!(status: :executed)
    end

    Result.new(parameter: parameter)
  end

  def execute_moderation_change(grant:)
    beneficiary = @proposal.beneficiary
    ActiveRecord::Base.transaction do
      grant ? beneficiary.grant_moderation! : beneficiary.revoke_moderation!
      @proposal.update!(status: :executed)
    end

    NotificationCreator.call(
      recipient:  beneficiary,
      notifiable: @proposal,
      kind:       "moderation_role",
      body:       grant ? "La comunidad te nombró moderador. Ya puedes resolver reportes y disputas en /moderacion." \
                        : "La comunidad revocó tu rol de moderador."
    )
    Result.new(meta: { user_id: beneficiary.id, granted: grant })
  end

  # Guarda "5" en vez de "5.0" cuando el valor es entero (EconomicParameter
  # almacena strings y los lectores usan get_int).
  def normalized_value
    value = Float(@proposal.parameter_value.to_s)
    value == value.to_i ? value.to_i.to_s : value.to_s
  end

  def fail(code, meta = {})
    Result.new(error: code, meta: meta)
  end
end
