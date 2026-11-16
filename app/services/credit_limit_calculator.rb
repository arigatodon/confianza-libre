class CreditLimitCalculator
  # Aplica la tabla de niveles de ECONOMIA.md § 4.1 y los thresholds de § 4.2.
  # Devuelve el conjunto {level, credit_floor, credit_ceiling, tx_cap} más alto
  # para el cual el usuario califica. Puede bajar si trust o cumplimiento se
  # deterioran (la función es monótona en los inputs, no recuerda el nivel
  # previo del usuario).
  #
  # Mantenemos los thresholds como tabla declarativa al inicio para que
  # ajustar la calibración no requiera tocar la lógica.

  LEVELS = {
    1 => { credit_floor:       100, credit_ceiling:       1_000, tx_cap:       50 },
    2 => { credit_floor:     1_000, credit_ceiling:      10_000, tx_cap:      250 },
    3 => { credit_floor:    10_000, credit_ceiling:     100_000, tx_cap:    1_000 },
    4 => { credit_floor:   100_000, credit_ceiling:   1_000_000, tx_cap:   10_000 },
    5 => { credit_floor: 1_000_000, credit_ceiling:  10_000_000, tx_cap:  100_000 }
  }.freeze

  # min_distinct: usuarios distintos con los que se completó interacción.
  # age_days crece con el nivel: a mayor cupo (y mayor pasivo comunitario que
  # la red absorbe ante un impago), exigimos más trayectoria. El nivel 5 otorga
  # un piso de -1.000.000: por eso pide la antigüedad más alta (180 días). Sin
  # ese piso temporal, una granja de cuentas sibilas podría inflar 200
  # interacciones con 100 contrapartes y saltar al cupo máximo en días.
  # (El rol de moderación ya NO depende del nivel — es un flag de gobernanza,
  # Fase 1.3 — así que subir de nivel no otorga poderes de policía.)
  REQUIREMENTS = {
    2 => { completed: 3,   distinct: 2,   trust: 3.5, age_days: 7,   verification: %w[email phone identity] },
    3 => { completed: 15,  distinct: 8,   trust: 4.0, age_days: 30,  verification: %w[email phone identity] },
    4 => { completed: 50,  distinct: 25,  trust: 4.3, age_days: 90,  verification: %w[phone identity] },
    5 => { completed: 200, distinct: 100, trust: 4.5, age_days: 180, verification: %w[identity] }
  }.freeze

  def self.call(user)
    new(user).call
  end

  def self.progress_to_next_level(user)
    new(user).progress_to_next_level
  end

  def initialize(user)
    @user = user
  end

  def call
    base = LEVELS[max_qualified_level].merge(level: max_qualified_level)
    # Padrinazgo: el bonus es aditivo al floor base del nivel y persiste
    # mientras la columna no se resetee. El techo y el tx_cap no se tocan.
    base.merge(credit_floor: base[:credit_floor] + @user.sponsor_bonus_floor.to_i)
  end

  # Devuelve un breakdown de qué le falta al usuario para subir al próximo
  # nivel, criterio por criterio. nil si ya está en el nivel máximo (5).
  def progress_to_next_level
    current = max_qualified_level
    return nil if current == 5

    target = current + 1
    req    = REQUIREMENTS[target]
    s      = stats

    [
      { label: "Interacciones completadas", current: s[:completed],       required: req[:completed], met: s[:completed]       >= req[:completed] },
      { label: "Contrapartes distintas",    current: s[:distinct_others], required: req[:distinct],  met: s[:distinct_others] >= req[:distinct] },
      { label: "Trust score",               current: s[:trust],           required: req[:trust],     met: s[:trust]           >= req[:trust], unit: "★" },
      { label: "Antigüedad (días)",         current: s[:age_days],        required: req[:age_days],  met: s[:age_days]        >= req[:age_days] },
      { label: "Verificación",              current: s[:verification],    required: req[:verification].first, met: req[:verification].include?(s[:verification]), kind: :enum }
    ]
  end

  private

  def stats
    @stats ||= compute_stats
  end

  def max_qualified_level
    @max_qualified_level ||= begin
      [ 5, 4, 3, 2 ].each do |lvl|
        return lvl if qualifies_for?(lvl, stats)
      end
      1
    end
  end

  def qualifies_for?(level, s)
    req = REQUIREMENTS[level]
    s[:completed]         >= req[:completed] &&
      s[:distinct_others] >= req[:distinct] &&
      s[:trust]           >= req[:trust] &&
      s[:age_days]        >= req[:age_days] &&
      req[:verification].include?(s[:verification])
  end

  def compute_stats
    completed_sent     = @user.interactions_sent.completed
    completed_received = @user.interactions_received.completed

    others = completed_sent.pluck(:receiver_id) + completed_received.pluck(:sender_id)

    {
      trust:           @user.trust_score.to_f,
      completed:       completed_sent.count + completed_received.count,
      distinct_others: others.uniq.size,
      age_days:        ((Time.current - @user.created_at) / 1.day).to_i,
      verification:    @user.verification_level.to_s
    }
  end
end
