class ReportResolver
  # Resuelve un reporte aplicando una acción (hide/warn/suspend/dismiss) y,
  # cuando corresponde, transfiere `mod_resolution_reward` créditos del fondo
  # territorial al moderador. Toda la operación corre en una sola DB tx.
  #
  # Reglas de autorización:
  #   - El moderador debe ser L3+ (User#moderator?).
  #   - No puede ser el autor del contenido reportado.
  #   - No puede ser el reporter del mismo reporte.
  #
  # Acciones:
  #   - :hide       — soft-hide del contenido (no aplica a User).
  #   - :warn       — notificación al autor.
  #   - :suspend    — sólo aplica si reportable es User.
  #   - :dismiss    — cierre sin acción. No paga reward.

  ACTIONS = %i[hide warn suspend dismiss].freeze

  Result = Struct.new(:report, :error, :reward_amount, :meta, keyword_init: true) do
    def ok? = report.present? && error.nil?
  end

  def self.call(report:, moderator:, action:, note: nil)
    new(report, moderator, action, note).call
  end

  def initialize(report, moderator, action, note)
    @report    = report
    @moderator = moderator
    @action    = action.to_sym
    @note      = note.to_s.strip.presence
  end

  def call
    return fail(:invalid_action)         unless ACTIONS.include?(@action)
    return fail(:not_open)               unless @report.open?
    return fail(:unauthorized)           unless @moderator&.moderator?
    return fail(:cannot_moderate_self)   if @moderator.id == @report.target_author&.id
    return fail(:cannot_moderate_own_report) if @moderator.id == @report.reporter_id
    return fail(:suspend_requires_user)  if @action == :suspend && @report.reportable_type != "User"

    new_status = STATUS_FOR_ACTION[@action]
    paid       = 0
    ActiveRecord::Base.transaction do
      apply_action!
      paid = pay_reward_if_eligible!
      @report.update!(
        status:          new_status,
        resolved_by:     @moderator,
        resolved_at:     Time.current,
        resolution_note: @note,
        reward_credits:  paid
      )
    end

    notify_author!

    Result.new(report: @report.reload, reward_amount: paid)
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn("[ReportResolver] #{e.message}")
    fail(:persistence_error, message: e.message)
  end

  private

  STATUS_FOR_ACTION = {
    hide:     :hidden,
    warn:     :warned,
    suspend:  :suspended,
    dismiss:  :dismissed
  }.freeze

  def apply_action!
    case @action
    when :hide
      target = @report.reportable
      return if target.is_a?(User)  # hide no aplica a users
      target.update!(hidden_at: Time.current)
    when :suspend
      @report.reportable.update!(status: :suspended) if @report.reportable.is_a?(User)
    when :warn, :dismiss
      # No-op sobre el reportable.
    end
  end

  # Reward = mod_resolution_reward (default 2 C) si:
  #   - action != dismiss
  #   - el territorio del contenido reportado tiene fondo suficiente.
  # Si no hay territorio o no alcanza, se paga 0 (la resolución igual procede).
  def pay_reward_if_eligible!
    return 0 if @action == :dismiss

    amount = EconomicParameter.get_int("mod_resolution_reward", 2)
    return 0 if amount <= 0

    territory = resolve_territory_for_reportable
    return 0 unless territory

    @report.update_column(:territory_id, territory.id)

    fund = territory.community_account
    return 0 unless fund && fund.cached_balance >= amount

    mod_acc = @moderator.ensure_credit_account!

    credit_tx = CreditTransaction.create!(
      source:           @report,
      territory:        territory,
      total_amount:     amount,
      burn_amount:      0,
      community_amount: 0,
      status:           :pending
    )
    credit_tx.ledger_entries.create!(account: fund,    direction: "debit",  amount: amount)
    credit_tx.ledger_entries.create!(account: mod_acc, direction: "credit", amount: amount)
    credit_tx.update!(status: :completed)

    fund.update!(cached_balance:    fund.cached_balance - amount)
    mod_acc.update!(cached_balance: mod_acc.cached_balance + amount)

    amount
  end

  def resolve_territory_for_reportable
    target = @report.reportable
    lat, lng =
      case target
      when Post          then [ target.latitude, target.longitude ]
      when Comment       then [ target.post.latitude, target.post.longitude ]
      when Message       then [ target.interaction.post.latitude, target.interaction.post.longitude ]
      # Un DM no tiene geo propia: usamos la del autor del mensaje.
      when DirectMessage then [ target.user.latitude, target.user.longitude ]
      when User          then [ target.latitude, target.longitude ]
      end
    return nil if lat.nil? || lng.nil?

    result = TerritoryResolver.resolve(lat, lng)
    result.ok? ? result.territory : nil
  end

  def notify_author!
    return if @action == :dismiss
    author = @report.target_author
    return unless author
    return if author.id == @moderator.id

    NotificationCreator.call(
      recipient:  author,
      actor:      @moderator,
      notifiable: @report,
      kind:       "moderation",
      body:       moderation_message
    )
  end

  def moderation_message
    case @action
    when :hide    then "Un moderador ocultó tu #{kind_label_es}. Motivo: #{@report.reason_label_es}."
    when :warn    then "Recibiste una advertencia por tu #{kind_label_es}. Motivo: #{@report.reason_label_es}."
    when :suspend then "Tu cuenta fue suspendida. Motivo: #{@report.reason_label_es}."
    end
  end

  def kind_label_es
    case @report.reportable_type
    when "Post"          then "publicación"
    when "Comment"       then "comentario"
    when "Message"       then "mensaje"
    when "DirectMessage" then "mensaje directo"
    when "User"          then "cuenta"
    else "contenido"
    end
  end

  def fail(code, meta = {})
    Result.new(error: code, meta: meta)
  end
end
