class Proposal < ApplicationRecord
  STATUSES = { open: 0, passed: 1, failed: 2, executed: 3, canceled: 4 }.freeze
  enum :status, STATUSES

  # Tipos de propuesta: además de gastar el fondo, la comunidad puede crear
  # categorías nuevas y cambiar las reglas económicas de la red (las "leyes").
  KINDS = { fund_transfer: 0, new_category: 1, rule_change: 2,
            grant_moderation: 3, revoke_moderation: 4 }.freeze
  enum :kind, KINDS

  STATUS_LABELS_ES = {
    "open"     => "Abierta",
    "passed"   => "Aprobada",
    "failed"   => "Rechazada",
    "executed" => "Ejecutada",
    "canceled" => "Cancelada"
  }.freeze

  KIND_LABELS_ES = {
    "fund_transfer"     => "Créditos del fondo",
    "new_category"      => "Nueva categoría",
    "rule_change"       => "Cambio de regla",
    "grant_moderation"  => "Nombrar moderador",
    "revoke_moderation" => "Revocar moderación"
  }.freeze

  # Parámetros económicos que la comunidad puede cambiar por votación, con
  # rangos seguros. Lo que no está aquí no es gobernable desde una propuesta.
  GOVERNABLE_PARAMETERS = {
    "burn_percent"              => { label: "Quema por transacción (%)",            min: 0,  max: 10,  step: 1 },
    "territory_percent"         => { label: "Aporte al fondo territorial (%)",      min: 0,  max: 10,  step: 1 },
    "proposal_quorum"           => { label: "Quórum de propuestas (votos)",         min: 1,  max: 100, step: 1 },
    "proposal_majority_percent" => { label: "Mayoría para aprobar (%)",             min: 50, max: 90,  step: 1 },
    "proposal_voting_days"      => { label: "Días de votación",                     min: 1,  max: 30,  step: 1 },
    "sponsor_floor_boost"       => { label: "Bonus de crédito por padrinazgo (C)",  min: 0,  max: 20,  step: 1 },
    "max_open_interactions_l1"  => { label: "Interacciones abiertas máx. nivel 1",  min: 0,  max: 10,  step: 1 },
    "mod_resolution_reward"     => { label: "Recompensa por moderar (C)",           min: 0,  max: 10,  step: 1 },
    "rules_quorum_percent"      => { label: "Quórum para reglas (% de la red activa)", min: 1, max: 50,   step: 1 },
    "endorsements_to_verify"    => { label: "Avales de vecinos para subir verificación", min: 1, max: 10, step: 1 },
    "territory_min_members_for_rules" => { label: "Miembros activos mínimos del territorio para proponer reglas", min: 0, max: 1000, step: 1 },
    "match_daily_cap"           => { label: "Avisos de match por día (máx. por usuario)", min: 0, max: 20, step: 1 }
  }.freeze

  belongs_to :territory
  belongs_to :proposer,              class_name: "User"
  belongs_to :beneficiary,           class_name: "User", optional: true
  belongs_to :execution_credit_transaction, class_name: "CreditTransaction", optional: true, inverse_of: nil

  has_many :votes, class_name: "ProposalVote", dependent: :destroy

  # Campos específicos del kind, guardados en el jsonb payload.
  store_accessor :payload, :category_name, :category_description,
                           :parameter_key, :parameter_value, :parameter_global

  # Un rule_change es local (override del territorio de la propuesta) salvo que
  # se marque como global (afecta a toda la red). Global exige quórum de red.
  def global_rule? = ActiveModel::Type::Boolean.new.cast(parameter_global)

  # Territorio al que aplica el override del rule_change (nil = global).
  def override_territory = global_rule? ? nil : territory

  validates :title, presence: true, length: { in: 5..120 }
  validates :body,  presence: true, length: { in: 10..2000 }
  validates :voting_closes_at, presence: true

  with_options if: :fund_transfer? do
    validates :beneficiary, presence: true
    validates :amount, numericality: { greater_than: 0, only_integer: true }
  end
  # Nombrar/revocar moderación: apuntan a un usuario (beneficiary). Nombrar a
  # uno mismo es el vector de abuso que 1.3 justamente evita — se bloquea.
  with_options if: :grant_moderation? do
    validates :beneficiary, presence: true
    validate  :beneficiary_not_already_moderator, on: :create
  end
  with_options if: :revoke_moderation? do
    validates :beneficiary, presence: true
    validate  :beneficiary_is_moderator, on: :create
  end

  # No proponerte a ti mismo como beneficiario (aplica a gastar el fondo y a
  # auto-nombrarte moderador). Se registra UNA sola vez para no chocar callbacks.
  validate :proposer_is_not_beneficiary, if: -> { fund_transfer? || grant_moderation? }

  # Sólo on: :create — al ejecutar, la categoría ya existe (la creó el propio
  # executor) y el update a :executed no debe rebotar contra estas reglas.
  validate :category_name_is_valid,    if: :new_category?, on: :create
  validate :parameter_change_is_valid, if: :rule_change?,  on: :create
  validate :proposer_meets_level_gate, on: :create
  validate :territory_meets_member_gate, on: :create

  before_validation :set_default_closing_time, on: :create

  scope :recent, -> { order(created_at: :desc) }

  def yes_votes;   votes.where(position: 1).count;  end
  def no_votes;    votes.where(position: -1).count; end
  def total_votes; votes.count;                     end

  def majority_pct
    return 0.0 if total_votes.zero?
    yes_votes.to_f / total_votes * 100
  end

  # Escalones de participación: para gastar el fondo alcanza el quórum base;
  # para cambiar reglas o crear categorías (efecto global) el quórum crece con
  # la red — un porcentaje de los miembros activos, nunca menos que la base.
  # Así, 3 votos pueden decidir cuando somos 20, pero no cuando seamos 10.000.
  def quorum_required
    base = EconomicParameter.get_int("proposal_quorum", 10)
    return base if fund_transfer?

    percent = EconomicParameter.get_decimal("rules_quorum_percent", 10.0)
    network = User.where(status: :active).count
    [ base, (network * percent / 100.0).ceil ].max
  end

  def majority_required_pct
    EconomicParameter.get_decimal("proposal_majority_percent", 60.0)
  end

  def quorum_met?;   total_votes  >= quorum_required;       end
  def majority_met?; majority_pct >= majority_required_pct; end
  def voting_closed?; voting_closes_at <= Time.current;     end

  # Lazy close: si la votación venció y todavía está open, transiciona a
  # passed o failed según quorum + mayoría. Idempotente.
  def close_if_due!
    return self unless open? && voting_closed?
    update!(status: (quorum_met? && majority_met?) ? :passed : :failed)
    self
  end

  def status_label_es
    STATUS_LABELS_ES[status] || status.to_s.humanize
  end

  def kind_label_es
    KIND_LABELS_ES[kind] || kind.to_s.humanize
  end

  def governable_parameter
    GOVERNABLE_PARAMETERS[parameter_key.to_s]
  end

  # Valor vigente del parámetro que esta propuesta quiere cambiar (el que aplica
  # en su alcance: el override local si es local, el global si es global).
  def current_parameter_value
    EconomicParameter.get(parameter_key.to_s, territory: override_territory)
  end

  # Nivel mínimo para proponer cambios estructurales (reglas y categorías).
  # Gastar el fondo queda abierto a cualquier miembro: el voto ya filtra.
  def self.rules_min_level
    EconomicParameter.get_int("proposal_rules_min_level", 2)
  end

  def voted_by?(user)
    return false unless user
    votes.exists?(user_id: user.id)
  end

  def vote_of(user)
    return nil unless user
    votes.find_by(user_id: user.id)
  end

  def fund_account;        territory.community_account;        end
  def beneficiary_account; beneficiary.ensure_credit_account!; end

  def fund_has_enough?
    fund_account&.cached_balance.to_i >= amount
  end

  private

  def proposer_is_not_beneficiary
    return unless proposer_id == beneficiary_id
    errors.add(:beneficiary_id, "no puedes proponerte a ti mismo como beneficiario")
  end

  def beneficiary_not_already_moderator
    return if beneficiary.nil?
    errors.add(:base, "@#{beneficiary.username} ya es moderador") if beneficiary.moderator?
  end

  def beneficiary_is_moderator
    return if beneficiary.nil?
    errors.add(:base, "@#{beneficiary.username} no es moderador") unless beneficiary.moderator?
  end

  def category_name_is_valid
    name = category_name.to_s.strip
    if name.length < 3 || name.length > 40
      errors.add(:base, "el nombre de la categoría debe tener entre 3 y 40 caracteres")
    elsif Category.where("LOWER(name) = ?", name.downcase).exists?
      errors.add(:base, "la categoría \"#{name}\" ya existe")
    end
  end

  def parameter_change_is_valid
    rule = governable_parameter
    if rule.nil?
      errors.add(:base, "ese parámetro no es gobernable por propuesta")
      return
    end

    value = Float(parameter_value.to_s, exception: false)
    if value.nil? || value < rule[:min] || value > rule[:max]
      errors.add(:base, "el valor para #{rule[:label]} debe estar entre #{rule[:min]} y #{rule[:max]}")
    end
  end

  def proposer_meets_level_gate
    return if fund_transfer?
    return if proposer.nil? || proposer.level.to_i >= self.class.rules_min_level

    errors.add(:base, "necesitas nivel #{self.class.rules_min_level} para proponer cambios de reglas o categorías — la confianza se gana participando")
  end

  # Escalón territorial: un territorio propone reglas cuando tiene suficientes
  # miembros activos. 0 = sin mínimo (red en arranque); el umbral es gobernable
  # y la idea es que suba a medida que la red crece.
  def territory_meets_member_gate
    return if fund_transfer? || territory.nil?

    min = EconomicParameter.get_int("territory_min_members_for_rules", 0)
    return if min.zero? || territory.active_members_count >= min

    errors.add(:base, "este territorio necesita al menos #{min} miembros activos para proponer cambios de reglas — invita a tus vecinos")
  end

  def set_default_closing_time
    days = EconomicParameter.get_int("proposal_voting_days", 7)
    self.voting_closes_at ||= days.days.from_now
  end
end
