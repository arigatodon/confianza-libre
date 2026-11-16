class DisputeResolver
  # Resuelve una disputa aplicando un veredicto (complete/partial/cancel).
  # Reusa CreditTransfer para mover créditos cuando corresponde. Toda la
  # operación corre en una sola DB tx.
  #
  # Reglas de autorización:
  #   - El moderador debe ser L3+ (User#moderator?).
  #   - No puede ser parte de la interacción en disputa.
  #
  # Veredictos:
  #   - :complete — cierra la interacción y transfiere `agreed_credits`.
  #   - :partial  — cierra la interacción y transfiere `amount` (0..agreed_credits).
  #   - :cancel   — cancela la interacción, no mueve crédito.

  VERDICTS = Dispute::VERDICTS.keys.map(&:to_s).freeze

  Result = Struct.new(:dispute, :error, :meta, keyword_init: true) do
    def ok? = dispute.present? && error.nil?
  end

  def self.call(dispute:, moderator:, verdict:, note: nil, amount: nil)
    new(dispute, moderator, verdict, note, amount).call
  end

  def initialize(dispute, moderator, verdict, note, amount)
    @dispute     = dispute
    @moderator   = moderator
    @verdict     = verdict.to_s
    @note        = note.to_s.strip.presence
    @amount      = amount
    @interaction = dispute.interaction
  end

  def call
    return fail(:invalid_verdict)      unless VERDICTS.include?(@verdict)
    return fail(:already_resolved)     if @dispute.resolved?
    return fail(:unauthorized)         unless @moderator&.moderator?
    return fail(:cannot_resolve_own)   if [ @interaction.sender_id, @interaction.receiver_id ].include?(@moderator.id)

    amount = resolution_amount
    if @verdict == "partial" && (amount.nil? || amount.negative? || amount > @interaction.agreed_credits)
      return fail(:invalid_amount)
    end

    transfer_result = nil
    ActiveRecord::Base.transaction do
      case @verdict
      when "complete" then transfer_result = close_and_transfer!(@interaction.agreed_credits)
      when "partial"  then transfer_result = close_and_transfer!(amount)
      when "cancel"   then @interaction.update!(status: :canceled)
      end

      raise ActiveRecord::Rollback if transfer_result && !transfer_result.ok?

      @dispute.update!(
        status:            :resolved,
        verdict:           @verdict,
        resolution_amount: @verdict == "cancel" ? nil : amount,
        resolution_note:   @note,
        resolved_by:       @moderator,
        resolved_at:       Time.current
      )
    end

    return fail(:transfer_failed, message: transfer_result.error.to_s) if transfer_result && !transfer_result.ok?

    notify_parties!
    Result.new(dispute: @dispute.reload)
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn("[DisputeResolver] #{e.message}")
    fail(:persistence_error, message: e.message)
  end

  private

  def resolution_amount
    case @verdict
    when "complete" then @interaction.agreed_credits
    when "partial"  then @amount.to_i
    end
  end

  # Cierra la interacción y transfiere créditos si el monto es positivo
  # (igual que el cierre normal por doble confirmación).
  def close_and_transfer!(amount)
    @interaction.update!(status: :completed) unless @interaction.completed?
    return nil unless amount.to_i.positive?

    CreditTransfer.call(@interaction, amount: amount)
  end

  def notify_parties!
    [ @interaction.sender, @interaction.receiver ].each do |party|
      NotificationCreator.call(
        recipient:  party,
        actor:      @moderator,
        notifiable: @dispute,
        kind:       "dispute_resolved",
        body:       "Un moderador resolvió la disputa: #{@dispute.verdict_label_es}." +
                    (@note ? " Nota: #{@note}" : "")
      )
      DisputeMailer.resolved(@dispute, party).deliver_later
    end
  end

  def fail(code, meta = {})
    Result.new(error: code, meta: meta)
  end
end
