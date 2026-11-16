class Report < ApplicationRecord
  REASONS  = { spam: 0, abuse: 1, harmful: 2, offtopic: 3, other: 4 }.freeze
  STATUSES = { open: 0, hidden: 1, warned: 2, suspended: 3, dismissed: 4 }.freeze

  REASON_LABELS_ES = {
    "spam"     => "Spam o publicidad",
    "abuse"    => "Acoso o abuso",
    "harmful"  => "Contenido dañino o ilegal",
    "offtopic" => "Fuera de tema",
    "other"    => "Otro motivo"
  }.freeze

  STATUS_LABELS_ES = {
    "open"      => "Abierto",
    "hidden"    => "Contenido oculto",
    "warned"    => "Autor advertido",
    "suspended" => "Usuario suspendido",
    "dismissed" => "Desestimado"
  }.freeze

  REPORTABLE_TYPES = %w[Post Comment Message DirectMessage User].freeze

  enum :reason, REASONS
  enum :status, STATUSES

  belongs_to :reporter,    class_name: "User"
  belongs_to :reportable,  polymorphic: true
  belongs_to :resolved_by, class_name: "User", optional: true
  belongs_to :territory,   optional: true

  validates :reportable_type, inclusion: { in: REPORTABLE_TYPES }
  validates :body, length: { maximum: 2000 }
  validate  :reporter_is_not_target_author

  scope :open_only, -> { where(status: :open) }
  scope :recent,    -> { order(created_at: :desc) }

  def reason_label_es
    REASON_LABELS_ES[reason] || reason.to_s.humanize
  end

  def status_label_es
    STATUS_LABELS_ES[status] || status.to_s.humanize
  end

  # Autor del contenido reportado (sirve para evitar self-report y para
  # validar que el moderador no es el autor).
  def target_author
    case reportable
    when Post, Comment, Message, DirectMessage then reportable.user
    when User                                  then reportable
    end
  end

  private

  def reporter_is_not_target_author
    return unless reporter && target_author
    return unless reporter_id == target_author.id
    errors.add(:base, "no puedes reportar tu propio contenido")
  end
end
