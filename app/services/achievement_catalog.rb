# Catálogo declarativo de logros, calculado al vuelo desde las stats del usuario
# (sin tabla: nada que persistir ni migrar). Cada logro se evalúa contra un
# snapshot de stats que se computa una sola vez por usuario.
#
# Uso:
#   cat = AchievementCatalog.new(user)
#   cat.badges            # => [Badge, ...] en orden de catálogo
#   cat.grouped           # => { "Identidad" => [Badge, ...], ... }
#   cat.unlocked_count    # => Integer
#   cat.total             # => Integer
class AchievementCatalog
  # Un logro resuelto para un usuario concreto.
  #   target nil  -> logro binario (bloqueado / desbloqueado)
  #   target Num  -> logro con progreso (current / target)
  Badge = Struct.new(
    :key, :name, :icon, :description, :category,
    :unlocked, :current, :target, :unit,
    keyword_init: true
  ) do
    def progress? = !target.nil?

    def percent
      return unlocked ? 100 : 0 unless progress?
      [ [ (current.to_f / target * 100).round, 0 ].max, 100 ].min
    end
  end

  CATEGORIES = %w[Identidad Actividad Reputación Comunidad Democracia Niveles].freeze

  def initialize(user)
    @user = user
  end

  def badges
    @badges ||= definitions.map { |d| resolve(d) }
  end

  def grouped
    badges.group_by(&:category).sort_by { |cat, _| CATEGORIES.index(cat) || 99 }.to_h
  end

  def unlocked_count = badges.count(&:unlocked)
  def total          = badges.size

  private

  attr_reader :user

  # ---- snapshot de stats (una sola pasada) ----
  def stats
    @stats ||= begin
      sent   = user.interactions_sent.completed
      recv   = user.interactions_received.completed
      others = sent.pluck(:receiver_id) + recv.pluck(:sender_id)
      {
        email_verified:   user.email_verified?,
        vlevel:           User.verification_levels[user.verification_level].to_i,
        profile_complete: user.avatar.attached? && user.bio.present?,
        posts:            user.posts.count,
        completed:        sent.count + recv.count,
        distinct:         others.uniq.size,
        reviews:          user.reviews_received.count,
        trust:            user.trust_score.to_f,
        level:            user.level.to_i,
        moderator:        user.moderator?,
        sponsored:        user.sponsored_users.count,
        pioneer:          user.id.to_i.positive? && user.id.to_i <= 100,
        votes:            user.proposal_votes.count,
        proposals:        user.proposals.count,
        proposals_passed: user.proposals.where(status: [ Proposal::STATUSES[:passed], Proposal::STATUSES[:executed] ]).count
      }
    end
  end

  # Cada definición es un hash con metadatos + un bloque `unlocked` y, si tiene
  # progreso, `current`/`target`. Los bloques reciben el snapshot de stats.
  def definitions
    s = stats
    [
      # --- Identidad ---
      { key: "email_verified", name: "Cuenta verificada", icon: "verified", category: "Identidad",
        description: "Verificaste tu correo electrónico.",
        unlocked: s[:email_verified] },
      { key: "profile_complete", name: "Perfil completo", icon: "badge", category: "Identidad",
        description: "Sumaste foto de perfil y una bio.",
        unlocked: s[:profile_complete] },
      { key: "phone_verified", name: "Teléfono verificado", icon: "phone_iphone", category: "Identidad",
        description: "Verificaste tu número de teléfono.",
        unlocked: s[:vlevel] >= 2 },
      { key: "identity_verified", name: "Identidad verificada", icon: "fingerprint", category: "Identidad",
        description: "Validaste tu identidad con documento.",
        unlocked: s[:vlevel] >= 3 },

      # --- Actividad ---
      { key: "first_post", name: "Primera publicación", icon: "campaign", category: "Actividad",
        description: "Publicaste tu primera oferta o pedido.",
        unlocked: s[:posts] >= 1 },
      { key: "active_publisher", name: "Publicador activo", icon: "grid_view", category: "Actividad",
        description: "Llegaste a 10 publicaciones.",
        unlocked: s[:posts] >= 10, current: s[:posts], target: 10 },
      { key: "first_deal", name: "Primer trato cerrado", icon: "handshake", category: "Actividad",
        description: "Cerraste tu primer intercambio.",
        unlocked: s[:completed] >= 1 },
      { key: "network_weaver", name: "Tejedor de red", icon: "hub", category: "Actividad",
        description: "Cerraste tratos con 10 personas distintas.",
        unlocked: s[:distinct] >= 10, current: s[:distinct], target: 10 },

      # --- Reputación ---
      { key: "first_review", name: "Primera reseña", icon: "star", category: "Reputación",
        description: "Alguien dejó la primera reseña sobre ti.",
        unlocked: s[:reviews] >= 1 },
      { key: "trust_builder", name: "Constructor de confianza", icon: "shield", category: "Reputación",
        description: "Tus vecinos te dan 4 estrellas o más.",
        unlocked: s[:trust] >= 4.0, current: s[:trust].round(1), target: 4.0, unit: "★" },

      # --- Comunidad ---
      { key: "sponsor", name: "Padrino", icon: "diversity_3", category: "Comunidad",
        description: "Invitaste al menos a una persona a la red.",
        unlocked: s[:sponsored] >= 1 },
      { key: "pioneer", name: "Pionero", icon: "rocket_launch", category: "Comunidad",
        description: "Estás entre las primeras 100 personas de Confianza.",
        unlocked: s[:pioneer] },
      { key: "curator", name: "Curador", icon: "local_police", category: "Comunidad",
        description: "La comunidad te eligió para cuidar la red.",
        unlocked: s[:moderator] },
      { key: "ambassador", name: "Embajador", icon: "groups", category: "Comunidad",
        description: "Cinco personas entraron a la red invitadas por ti.",
        unlocked: s[:sponsored] >= 5, current: s[:sponsored], target: 5 },

      # --- Democracia ---
      { key: "first_vote", name: "Primer voto", icon: "how_to_vote", category: "Democracia",
        description: "Votaste en una propuesta comunitaria.",
        unlocked: s[:votes] >= 1 },
      { key: "active_voice", name: "Voz activa", icon: "ballot", category: "Democracia",
        description: "Participaste en 10 votaciones.",
        unlocked: s[:votes] >= 10, current: s[:votes], target: 10 },
      { key: "proposer", name: "Proponente", icon: "gavel", category: "Democracia",
        description: "Presentaste tu primera propuesta a la comunidad.",
        unlocked: s[:proposals] >= 1 },
      { key: "reformer", name: "Reformista", icon: "balance", category: "Democracia",
        description: "Una propuesta tuya fue aprobada por la comunidad.",
        unlocked: s[:proposals_passed] >= 1 },

      # --- Niveles ---
      { key: "level_2", name: "Nivel 2", icon: "military_tech", category: "Niveles",
        description: "Subiste al nivel 2.",
        unlocked: s[:level] >= 2, current: s[:level], target: 2 },
      { key: "level_3", name: "Nivel 3", icon: "military_tech", category: "Niveles",
        description: "Subiste al nivel 3.",
        unlocked: s[:level] >= 3, current: s[:level], target: 3 },
      { key: "level_4", name: "Nivel 4", icon: "military_tech", category: "Niveles",
        description: "Subiste al nivel 4.",
        unlocked: s[:level] >= 4, current: s[:level], target: 4 },
      { key: "level_5", name: "Nivel 5", icon: "workspace_premium", category: "Niveles",
        description: "Llegaste al nivel máximo.",
        unlocked: s[:level] >= 5, current: s[:level], target: 5 }
    ]
  end

  def resolve(d)
    Badge.new(
      key:         d[:key],
      name:        d[:name],
      icon:        d[:icon],
      description: d[:description],
      category:    d[:category],
      unlocked:    !!d[:unlocked],
      current:     d[:current],
      target:      d[:target],
      unit:        d[:unit]
    )
  end
end
