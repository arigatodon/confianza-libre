class Dispute < ApplicationRecord
  # Una disputa congela la interacción hasta que un moderador (que no es
  # parte) dicta veredicto. Solo se puede abrir ANTES de que se muevan
  # créditos (accepted / in_progress) — las quejas post-cierre van por
  # reviews o reportes, porque todavía no existe reversa de transacciones.

  MIN_ARGUMENT_LENGTH = 30
  DISPUTABLE_STATUSES = %w[accepted in_progress].freeze

  STATUSES = { open: 0, responded: 1, resolved: 2 }.freeze
  VERDICTS = { complete: 0, partial: 1, cancel: 2 }.freeze

  STATUS_LABELS_ES = {
    "open"      => "Abierta",
    "responded" => "Respondida",
    "resolved"  => "Resuelta"
  }.freeze

  VERDICT_LABELS_ES = {
    "complete" => "Intercambio completado",
    "partial"  => "Completado con monto ajustado",
    "cancel"   => "Cancelado sin mover créditos"
  }.freeze

  enum :status,  STATUSES
  enum :verdict, VERDICTS, prefix: :verdict

  belongs_to :interaction
  belongs_to :opener,      class_name: "User"
  belongs_to :resolved_by, class_name: "User", optional: true

  validates :argument, presence: true,
                       length: { minimum: MIN_ARGUMENT_LENGTH, maximum: 2000 }
  validates :response, presence: true, length: { maximum: 2000 }, if: :responded?
  validates :interaction_id, uniqueness: { message: "ya tiene una disputa" }
  validate  :opener_is_participant
  validate  :interaction_is_disputable, on: :create

  after_create_commit :notify_opened
  after_update_commit :notify_response, if: :saved_change_to_responded_at

  scope :unresolved,   -> { where.not(status: :resolved) }
  scope :oldest_first, -> { order(created_at: :asc) }

  # La otra parte de la interacción (quien puede responder la disputa).
  def counterpart
    interaction&.other_party(opener)
  end

  def verdict_label_es
    VERDICT_LABELS_ES[verdict] || verdict.to_s.humanize
  end

  def status_label_es
    STATUS_LABELS_ES[status] || status.to_s.humanize
  end

  # Una disputa "vieja" se destaca en el panel de moderación para que no
  # quede crédito congelado indefinidamente. Umbral gobernable.
  def self.stale_threshold_days
    EconomicParameter.get_int("dispute_auto_escalate_days", 7)
  end

  def stale?
    !resolved? && created_at <= self.class.stale_threshold_days.days.ago
  end

  def days_open
    ((Time.current - created_at) / 1.day).floor
  end

  private

  # La notificación in-app del cambio de estado la emite Interaction
  # (notify_status_change al pasar a :disputed); acá va solo el email,
  # que necesita el argumento de la disputa.
  def notify_opened
    DisputeMailer.opened(self).deliver_later
  end

  def notify_response
    return unless counterpart
    NotificationCreator.call(
      recipient:  opener,
      actor:      counterpart,
      notifiable: self,
      kind:       "dispute_response",
      body:       "@#{counterpart.username} respondió tu disputa. La revisará un moderador."
    )
    DisputeMailer.responded(self).deliver_later
  end

  def opener_is_participant
    return unless interaction && opener
    return if [ interaction.sender_id, interaction.receiver_id ].include?(opener_id)

    errors.add(:base, "solo las partes de la interacción pueden abrir una disputa")
  end

  def interaction_is_disputable
    return unless interaction
    return if DISPUTABLE_STATUSES.include?(interaction.status)

    errors.add(:base, "solo se puede abrir disputa con la interacción aceptada o en curso")
  end
end
