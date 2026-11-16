# Seeds idempotentes — base mínima para arrancar el MVP.
# Los territorios NO se siembran: se descubren lazy a medida que los usuarios
# publican (ver ECONOMIA.md § 5). Aquí sólo dejamos preparadas las piezas
# globales: categorías, cuentas globales y parámetros económicos.

# ----------------------------------------------------------------------------
# 1. Categorías (con multiplicador de crédito según ECONOMIA.md § 4.3).
#    El kind inferido (ver Post::CATEGORY_TO_KIND) determina el multiplicador.
# ----------------------------------------------------------------------------
categories = [
  { name: "Servicios",   trust_weight: 3, allows_credit: true,  multiplier: 1.0, publishable: true  },
  { name: "Productos",   trust_weight: 2, allows_credit: true,  multiplier: 1.2, publishable: true  },
  { name: "Delivery",    trust_weight: 4, allows_credit: true,  multiplier: 1.3, publishable: true  },
  { name: "Eventos",     trust_weight: 2, allows_credit: false, multiplier: 0.5, publishable: true  },
  { name: "Ayuda",       trust_weight: 1, allows_credit: false, multiplier: 0.7, publishable: true  },
  { name: "Comunidad",   trust_weight: 1, allows_credit: false, multiplier: 0.3, publishable: true  },
  { name: "Información", trust_weight: 1, allows_credit: false, multiplier: 0.2, publishable: true  },
  # Categoría interna — no aparece en el selector del post. Tagea las
  # reviews del dueño del post hacia el sender (reputación como cliente).
  { name: "Cliente",     trust_weight: 2, allows_credit: false, multiplier: 1.0, publishable: false }
]

categories.each do |attrs|
  cat = Category.find_or_initialize_by(name: attrs[:name])
  cat.trust_weight          = attrs[:trust_weight]
  cat.allows_credit         = attrs[:allows_credit]
  cat.max_credit_multiplier = attrs[:multiplier]
  cat.publishable           = attrs[:publishable]
  cat.save!
end
puts "Categorías: #{Category.count}"

# ----------------------------------------------------------------------------
# 2. Cuentas globales (burn + system).
#    burn   = acumula créditos quemados (sólo crece, nunca se gasta).
#    system = ajustes administrativos (refunds, correcciones).
# ----------------------------------------------------------------------------
%w[burn system].each do |type|
  Account.find_or_create_by!(account_type: type) do |a|
    a.cached_balance = 0
  end
end
puts "Cuentas globales: burn=#{Account.find_by(account_type: 'burn').id}, system=#{Account.find_by(account_type: 'system').id}"

# ----------------------------------------------------------------------------
# 3. Parámetros económicos globales (editables sin deploy).
#    Ver ECONOMIA.md § 3 y § 5.
# ----------------------------------------------------------------------------
parameters = [
  { key: "burn_percent",              value: "2",    description: "Porcentaje del total que se quema en cada transacción." },
  { key: "territory_percent",         value: "3",    description: "Porcentaje del total que va al fondo territorial." },
  { key: "allowed_countries",         value: "CL",   description: "Códigos ISO 3166-1 alfa-2 separados por coma. Países donde la app habilita territorios." },
  { key: "min_burn_amount",           value: "1",    description: "Quema mínima absoluta por transacción (evita microabuso)." },
  { key: "decay_check_days",          value: "90",   description: "Días sin reviews positivas antes de aplicar decay al credit_floor." },
  { key: "decay_rate_per_run",        value: "0.05", description: "Fracción del credit_floor que se reduce por cada corrida del job." },
  { key: "positive_review_threshold", value: "4",    description: "Score mínimo (1..5) que cuenta como review positiva para evitar el decay." },
  { key: "proposal_quorum",           value: "2",    description: "Votos mínimos para que una propuesta pase. ECONOMIA.md sugiere 10, bajo para fase desarrollo." },
  { key: "proposal_majority_percent", value: "60",   description: "Porcentaje de votos a favor requerido para aprobar una propuesta." },
  { key: "proposal_voting_days",      value: "7",    description: "Días que dura abierta la votación de una propuesta." },
  { key: "proposal_rules_min_level",  value: "1",    description: "Nivel mínimo para proponer cambios de reglas o categorías nuevas. 1 = cualquier persona con email verificado; el quórum filtra." },
  { key: "credit_ceiling",            value: "5000", description: "Techo de saldo, el mismo para todas las personas (ECONOMIA.md § 4.1). Lo que lo supera va al fondo territorial. Solo gobernable a nivel global." },
  { key: "rules_quorum_percent",      value: "10",   description: "Quórum para propuestas de reglas/categorías como % de los miembros activos de la red (nunca menor al quórum base)." },
  { key: "territory_min_members_for_rules", value: "0", description: "Miembros activos mínimos que necesita un territorio para proponer reglas/categorías. 0 = sin mínimo (red en arranque)." },
  { key: "endorsements_to_verify",    value: "3",    description: "Avales de vecinos nivel 3+ necesarios para subir la verificación de email a 'avalado por vecinos'." },
  { key: "max_open_interactions_l1",  value: "3",    description: "Máximo de interactions abiertas simultáneas para usuarios L1 (anti-spam / anti-multicuenta). 0 desactiva el límite." },
  { key: "mod_resolution_reward",     value: "2",    description: "Créditos del fondo territorial que se transfieren al moderador por cada reporte resuelto con acción (no aplica a desestimados). 0 desactiva el reward." },
  { key: "match_daily_cap",           value: "5",    description: "Máximo de avisos de match (pedidos/ofertas compatibles) por usuario por día." }
]

parameters.each do |attrs|
  param = EconomicParameter.find_or_initialize_by(key: attrs[:key])
  param.value       = attrs[:value]  if param.new_record?
  param.description = attrs[:description]
  param.save!
end
puts "Parámetros económicos: #{EconomicParameter.count}"

# ----------------------------------------------------------------------------
# 4. Backfill: asegurar que todos los usuarios tengan su Account 'user'.
#    Para usuarios nuevos esto lo hace el callback after_create_commit;
#    aquí cubrimos los que se crearon antes de existir el callback.
# ----------------------------------------------------------------------------
backfilled = 0
User.find_each do |u|
  next if u.credit_account
  u.ensure_credit_account!
  backfilled += 1
end
puts "Cuentas de usuario: total=#{Account.where(account_type: 'user').count} (#{backfilled} backfilleadas)"

puts ""
puts "Seed listo. Territorios = #{Territory.count} (se irán creando con la primera publicación de cada comuna)."
