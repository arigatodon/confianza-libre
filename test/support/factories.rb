module Factories
  # Crea categorías base si no existen — el seed de prod las crea pero el
  # test env empieza vacío.
  def ensure_base_categories!
    @categories_seeded ||= begin
      seed = {
        "Servicios"   => { trust_weight: 3, allows_credit: true,  multiplier: 1.0, publishable: true  },
        "Productos"   => { trust_weight: 2, allows_credit: true,  multiplier: 1.2, publishable: true  },
        "Información" => { trust_weight: 1, allows_credit: false, multiplier: 0.2, publishable: true  },
        # Categoría interna obligatoria: Review#before_validation la usa
        # cuando el reviewer es el dueño del post (rol de cliente).
        "Cliente"     => { trust_weight: 2, allows_credit: false, multiplier: 1.0, publishable: false }
      }
      seed.each do |name, attrs|
        Category.find_or_create_by!(name: name) do |c|
          c.trust_weight          = attrs[:trust_weight]
          c.allows_credit         = attrs[:allows_credit]
          c.max_credit_multiplier = attrs[:multiplier]
          c.publishable           = attrs[:publishable]
        end
      end
      Category.instance_variable_set(:@client, nil)  # invalidar el memo de Category.client
      true
    end
  end

  # Asegura las cuentas globales burn + system.
  def ensure_global_accounts!
    Account.find_or_create_by!(account_type: "burn")   { |a| a.cached_balance = 0 }
    Account.find_or_create_by!(account_type: "system") { |a| a.cached_balance = 0 }
  end

  # Carga los parámetros económicos mínimos para que CreditTransfer y otros
  # servicios encuentren defaults explícitos.
  def ensure_economic_parameters!
    params = {
      "burn_percent"              => "2",
      "territory_percent"         => "3",
      "allowed_countries"         => "CL",
      "min_burn_amount"           => "1",
      "decay_check_days"          => "90",
      "decay_rate_per_run"        => "0.05",
      "positive_review_threshold" => "4",
      "proposal_quorum"           => "2",
      "proposal_majority_percent" => "60",
      "proposal_voting_days"      => "7",
      "proposal_rules_min_level"  => "2",
      "rules_quorum_percent"      => "10",
      "territory_min_members_for_rules" => "0",
      "endorsements_to_verify"    => "3",
      "max_open_interactions_l1"  => "3",
      "match_daily_cap"           => "5"
    }
    params.each do |key, value|
      EconomicParameter.find_or_create_by!(key: key) { |p| p.value = value }
    end
    EconomicParameter.reset_cache!
  end

  # Atajo para overrides puntuales de parámetros económicos en tests:
  # invalida el cache del proceso después del update.
  def set_param(key, value)
    p = EconomicParameter.find_or_create_by!(key: key.to_s) { |r| r.value = value.to_s }
    p.update!(value: value.to_s) unless p.value == value.to_s
    EconomicParameter.reset_cache!
  end

  def setup_economy!
    ensure_base_categories!
    ensure_global_accounts!
    ensure_economic_parameters!
  end

  # email_verified: por default true en tests — la mayoría asume usuarios que
  # ya pueden transaccionar. Pasá email_verified: false explícitamente para
  # cubrir flujos de onboarding.
  def create_user(username: nil, email_verified: true, onboarded: true, **attrs)
    username ||= "u#{SecureRandom.hex(3)}"
    user = User.create!(
      {
        username:        username,
        email_address:   "#{username}@test.local",
        password:        "password123",
        password_confirmation: "password123"
      }.merge(attrs)
    )
    user.ensure_credit_account!
    if email_verified
      user.update_columns(
        email_verified_at:   Time.current,
        verification_level:  User::VERIFICATION_LEVELS[:email]
      )
    end
    user.update_columns(onboarding_completed_at: Time.current) if onboarded
    user
  end

  def create_post(user:, category: nil, **attrs)
    ensure_base_categories!
    category ||= Category.find_by!(name: "Servicios")
    user.posts.create!(
      {
        title:       "Post de #{user.username}",
        description: "Cuerpo",
        category:    category,
        kind:        "venta",
        status:      :published,
        latitude:    -33.5413,
        longitude:   -71.6111,
        visibility_radius: 5_000
      }.merge(attrs)
    )
  end

  def create_interaction(post:, sender:, receiver:, status: :requested, agreed_credits: 0)
    post.interactions.create!(
      sender:         sender,
      receiver:       receiver,
      status:         status,
      agreed_credits: agreed_credits
    )
  end

  # Construye una Interaction completed con CreditTransfer ya ejecutado.
  # Útil para tests que parten de "ya hubo intercambio económico".
  def create_completed_interaction(sender:, receiver:, agreed_credits: 50, category_name: "Servicios")
    setup_economy!
    cat  = Category.find_by!(name: category_name)
    post = create_post(user: receiver, category: cat)
    i    = create_interaction(post: post, sender: sender, receiver: receiver,
                              status: :in_progress, agreed_credits: agreed_credits)
    i.update!(sender_completed_at: Time.current, receiver_completed_at: Time.current)
    i.update!(status: :completed)
    CreditTransfer.call(i) if agreed_credits.positive?
    i.reload
  end

  def create_review(interaction:, reviewer:, score: 5, comment: "Bien")
    reviewed = interaction.other_party(reviewer)
    # category y category_weight los setea Review.before_validation según rol.
    interaction.post.reviews.create!(
      reviewer:      reviewer,
      reviewed_user: reviewed,
      interaction:   interaction,
      score:         score,
      comment:       comment
    )
  end
end
