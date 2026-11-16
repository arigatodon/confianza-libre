class CreditTransfer
  # Ejecuta una transferencia de créditos asociada a una Interaction.
  #
  # En una sola DB transaction:
  #   - Valida tope por categoría (tx_cap × max_credit_multiplier).
  #   - Valida piso del sender (no rompe credit_floor).
  #   - Aplica techo del receiver (excedente va al fondo territorial).
  #   - Crea CreditTransaction + 4 LedgerEntry balanceados.
  #   - Actualiza cached_balance de todas las cuentas tocadas.
  #
  # Uso:
  #   result = CreditTransfer.call(interaction)
  #   result.ok?                # => true / false
  #   result.credit_transaction # => CreditTransaction (cuando ok?)
  #   result.error              # => :exceeds_tx_cap | :insufficient_balance | ...
  #   result.breakdown          # => { total:, burn:, territory:, receiver: }

  Result = Struct.new(:credit_transaction, :error, :breakdown, :meta, keyword_init: true) do
    def ok? = credit_transaction.present?
  end

  def self.call(interaction, amount: nil)
    new(interaction, amount).call
  end

  def initialize(interaction, amount = nil)
    @interaction = interaction
    @amount      = (amount || interaction.agreed_credits).to_i
  end

  def call
    return fail(:zero_amount)      if @amount <= 0
    return fail(:not_completed)    unless @interaction.completed?
    return fail(:already_settled)  if @interaction.credit_transaction.present?

    @sender   = @interaction.sender
    @receiver = @interaction.receiver
    @post     = @interaction.post
    @category = @post.category

    sender_acc   = @sender.ensure_credit_account!
    receiver_acc = @receiver.ensure_credit_account!

    # 1. Tope por categoría y nivel.
    max_per_tx = (@sender.tx_cap * @category.max_credit_multiplier.to_f).floor
    return fail(:exceeds_tx_cap, max_allowed: max_per_tx) if @amount > max_per_tx

    # 2. Piso del sender (no rompe -credit_floor).
    available = sender_acc.cached_balance + @sender.credit_floor
    return fail(:insufficient_balance, available: available) if available < @amount

    # 3. Resolver territorio (fallback al system si Geocoder falla). Se hace
    #    antes del desglose porque la quema y el aporte al fondo pueden tener
    #    override local en ese territorio (Fase 3.1).
    target = resolve_territory_target
    territory_account = target[:account]
    territory_record  = target[:territory]

    # 4. Cálculo del desglose con las reglas del territorio de la transacción.
    breakdown = compute_breakdown(receiver_acc, territory_record)
    return fail(:invalid_breakdown) unless breakdown

    # 5. Ejecutar la transacción.
    credit_tx = nil
    ActiveRecord::Base.transaction do
      credit_tx = @interaction.build_credit_transaction(
        total_amount:     @amount,
        burn_amount:      breakdown[:burn],
        community_amount: breakdown[:territory],
        territory:        territory_record,
        category:         @category,
        status:           :pending
      )
      credit_tx.save!

      write_entry!(credit_tx, sender_acc,         "debit",  @amount)
      write_entry!(credit_tx, receiver_acc,       "credit", breakdown[:receiver])
      write_entry!(credit_tx, territory_account,  "credit", breakdown[:territory])
      write_entry!(credit_tx, burn_account,       "credit", breakdown[:burn])

      credit_tx.status = :completed
      credit_tx.save!  # dispara la validación ledger_must_balance

      apply_balance!(sender_acc,        -@amount)
      apply_balance!(receiver_acc,      breakdown[:receiver])
      apply_balance!(territory_account, breakdown[:territory])
      apply_balance!(burn_account,      breakdown[:burn])
    end

    Result.new(credit_transaction: credit_tx, breakdown: breakdown)
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn("[CreditTransfer] RecordInvalid: #{e.message}")
    Result.new(error: :persistence_error, meta: { message: e.message })
  end

  private

  def compute_breakdown(receiver_acc, territory = nil)
    burn_pct = EconomicParameter.get_decimal("burn_percent",      2.0, territory: territory)
    terr_pct = EconomicParameter.get_decimal("territory_percent", 3.0, territory: territory)
    min_burn = EconomicParameter.get_int("min_burn_amount", 1, territory: territory)

    burn      = [ (@amount * burn_pct / 100.0).round, min_burn ].max
    territory = (@amount * terr_pct / 100.0).round
    receiver_raw = @amount - burn - territory
    return nil if receiver_raw < 0

    # Techo del receiver: si supera credit_ceiling, el excedente va al territorio.
    room     = @receiver.credit_ceiling - receiver_acc.cached_balance
    capped   = [ [ receiver_raw, room ].min, 0 ].max
    overflow = receiver_raw - capped

    { total:     @amount,
      burn:      burn,
      territory: territory + overflow,
      receiver:  capped }
  end

  def resolve_territory_target
    if @post.latitude && @post.longitude
      result = TerritoryResolver.resolve(@post.latitude, @post.longitude)
      if result.ok?
        return { account: result.territory.community_account, territory: result.territory }
      end
    end
    # Fallback: sin territorio resoluble → el impuesto va a system_account.
    { account: system_account, territory: nil }
  end

  def write_entry!(credit_tx, account, direction, amount)
    return if amount.zero?
    credit_tx.ledger_entries.create!(account: account, direction: direction, amount: amount)
  end

  def apply_balance!(account, delta)
    return if delta.zero?
    account.update!(cached_balance: account.cached_balance + delta)
  end

  def burn_account
    @burn_account ||= Account.find_by!(account_type: "burn")
  end

  def system_account
    @system_account ||= Account.find_by!(account_type: "system")
  end

  def fail(code, meta = {})
    Result.new(error: code, meta: meta)
  end
end
