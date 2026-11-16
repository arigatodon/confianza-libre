class Feedback < ApplicationRecord
  KINDS = { bug: 0, idea: 1, love: 2, other: 3 }.freeze
  # `new` colisiona con Feedback.new (constructor), por eso uso :pending.
  STATUSES = { pending: 0, read: 1, done: 2, archived: 3 }.freeze

  KIND_LABELS_ES = {
    "bug"   => "Bug / problema",
    "idea"  => "Idea o sugerencia",
    "love"  => "Algo que me gusta",
    "other" => "Otro"
  }.freeze

  STATUS_LABELS_ES = {
    "pending"  => "Sin leer",
    "read"     => "Leído",
    "done"     => "Resuelto",
    "archived" => "Archivado"
  }.freeze

  enum :kind,   KINDS
  enum :status, STATUSES

  belongs_to :user, optional: true

  validates :body, presence: true, length: { minimum: 5, maximum: 4000 }

  scope :recent,     -> { order(created_at: :desc) }
  scope :unresolved, -> { where(status: [ :pending, :read ]) }

  def kind_label_es
    KIND_LABELS_ES[kind] || kind.to_s.humanize
  end

  def status_label_es
    STATUS_LABELS_ES[status] || status.to_s.humanize
  end
end
