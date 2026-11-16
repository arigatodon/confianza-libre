namespace :demo do
  desc "Crea un grupo de 10 usuarios demo en Santiago con posts, padrinazgos e interactions en distintos estados. Idempotente."
  task seed: :environment do
    unless Rails.env.development? || ENV["FORCE"] == "1"
      abort "demo:seed sólo corre en development. Para forzar: FORCE=1 bin/rails demo:seed"
    end

    # Sanity: el seed base debe haber corrido (categorías + cuentas globales + params).
    if Category.count.zero? || Account.where(account_type: "burn").none?
      puts "→ Falta el seed base. Corriendo db:seed primero…"
      Rake::Task["db:seed"].invoke
    end

    password = "demo1234"

    users_spec = [
      { username: "ana",    bio: "Peluquera y maquilladora. Atiendo a domicilio.",
        lat: -33.4264, lng: -70.6105 }, # Providencia
      { username: "beto",   bio: "Panadero de masa madre. Hornadas martes y viernes.",
        lat: -33.4570, lng: -70.5969 }, # Ñuñoa
      { username: "cami",   bio: "Repartidora en bici. Almuerzos y mandados.",
        lat: -33.4140, lng: -70.5810 }, # Las Condes
      { username: "diego",  bio: "Mecánico de bicicletas. Taller en casa.",
        lat: -33.5111, lng: -70.7580 }, # Maipú
      { username: "elsa",   bio: "Voluntaria de barrio. Acompaño y ayudo con compras.",
        lat: -33.5226, lng: -70.5985 }, # La Florida
      { username: "felipe", bio: "Electricista certificado SEC. Urgencias 24/7.",
        lat: -33.4877, lng: -70.5395 }, # Peñalolén
      { username: "gaby",   bio: "Huerta urbana familiar. Verduras de temporada.",
        lat: -33.3863, lng: -70.5773 }, # Vitacura
      { username: "hugo",   bio: "Organizo eventos chicos: cumpleaños, juntas, asados.",
        lat: -33.4895, lng: -70.6516 }, # San Miguel
      { username: "ines",   bio: "Profe de mate. Clases para escolares y PSU.",
        lat: -33.4422, lng: -70.5444, sponsor: "ana" }, # La Reina
      { username: "julian", bio: "Reparo celulares y notebooks. Service rápido.",
        lat: -33.4036, lng: -70.6504, sponsor: "beto" }  # Recoleta
    ]

    puts "→ Usuarios"
    users = {}
    users_spec.each do |spec|
      user = User.find_or_initialize_by(username: spec[:username])
      is_new = user.new_record?
      user.assign_attributes(
        email_address: "#{spec[:username]}@demo.local",
        bio:           spec[:bio],
        latitude:      spec[:lat],
        longitude:     spec[:lng]
      )
      if is_new
        user.password              = password
        user.password_confirmation = password
      end
      user.save!
      # Verificación de email + cuenta + nivel inicial — sin emails ni jobs.
      # Onboarding lo completamos para todos excepto ines/julian (los apadrinados
      # nuevos) — así se puede probar el tour entrando como ellos.
      mark_onboarded = !%w[ines julian].include?(spec[:username])
      cols = {
        email_verified_at:  user.email_verified_at || Time.current,
        verification_level: User::VERIFICATION_LEVELS[:email]
      }
      cols[:onboarding_completed_at] = Time.current if mark_onboarded
      user.update_columns(cols)
      user.ensure_credit_account!
      users[spec[:username]] = user
      print(is_new ? "+" : ".")
    end
    puts " (#{users.size})"

    # Padrinazgos — sponsor_bonus_floor aditivo al credit_floor calculado.
    puts "→ Padrinazgos"
    sponsor_boost = EconomicParameter.get_int("sponsor_floor_boost", 5)
    users_spec.select { |s| s[:sponsor] }.each do |spec|
      ahijado = users[spec[:username]]
      padrino = users[spec[:sponsor]]
      next unless ahijado && padrino
      next if ahijado.sponsor_id == padrino.id

      ahijado.update!(sponsor_id: padrino.id)
      ahijado.update_columns(sponsor_bonus_floor: sponsor_boost) if ahijado.sponsor_bonus_floor.zero?
      puts "  @#{ahijado.username} apadrinado por @#{padrino.username} (+#{sponsor_boost}C floor)"
    end

    cat = ->(name) { Category.find_by!(name: name) }

    posts_spec = [
      { owner: "ana",    title: "Corte y peinado a domicilio",            cat: "Servicios", suggested: 30 },
      { owner: "beto",   title: "Pan de masa madre — hornada de la semana", cat: "Productos", suggested: 8 },
      { owner: "cami",   title: "Delivery de almuerzos en Las Condes",     cat: "Delivery",  suggested: 5 },
      { owner: "diego",  title: "Reparación de bicicletas y aros",         cat: "Servicios", suggested: 40 },
      { owner: "elsa",   title: "Ayuda con compras del super para vecinos", cat: "Ayuda",     suggested: 0 },
      { owner: "felipe", title: "Instalaciones eléctricas certificadas",   cat: "Servicios", suggested: 80 },
      { owner: "gaby",   title: "Verduras orgánicas de la huerta",         cat: "Productos", suggested: 12 },
      { owner: "hugo",   title: "Organizo cumpleaños y juntas",            cat: "Eventos",   suggested: 60 },
      { owner: "ines",   title: "Clases particulares de matemática",       cat: "Servicios", suggested: 25 },
      { owner: "julian", title: "Reparación de celulares y notebooks",     cat: "Servicios", suggested: 35 }
    ]

    puts "→ Publicaciones"
    posts = {}
    posts_spec.each do |spec|
      owner = users[spec[:owner]]
      post = owner.posts.find_or_initialize_by(title: spec[:title])
      is_new = post.new_record?
      post.assign_attributes(
        description:       "Demo: #{spec[:title]} — publicado por @#{owner.username}.",
        category:          cat.call(spec[:cat]),
        latitude:          owner.latitude,
        longitude:         owner.longitude,
        visibility_radius: 5_000,
        status:            :published,
        suggested_credits: spec[:suggested]
      )
      post.save!
      posts[spec[:owner]] = post
      print(is_new ? "+" : ".")
    end
    puts " (#{posts.size})"

    # Helpers locales --------------------------------------------------------
    upsert_interaction = lambda do |post:, sender:, receiver:, status:, agreed:|
      existing = Interaction.find_by(post: post, sender: sender, receiver: receiver)
      return existing if existing
      Interaction.create!(post: post, sender: sender, receiver: receiver,
                          status: status, agreed_credits: agreed)
    end

    complete_with_transfer = lambda do |interaction:, amount:|
      # Si ya tiene credit_transaction, asumir cerrada y skip.
      return interaction if interaction.credit_transaction.present?

      interaction.update_columns(
        status:               Interaction::STATUSES[:in_progress],
        agreed_credits:       amount,
        sender_completed_at:  Time.current,
        receiver_completed_at: Time.current
      )
      interaction.update_columns(status: Interaction::STATUSES[:completed])
      result = CreditTransfer.call(interaction.reload)
      unless result.ok?
        puts "  ⚠ CreditTransfer falló para interaction ##{interaction.id}: #{result.error} #{result.meta}"
      end
      interaction.reload
    end

    add_review = lambda do |interaction:, reviewer:, score:, comment:|
      return if interaction.reviews.where(reviewer_id: reviewer.id).exists?
      reviewed = interaction.other_party(reviewer)
      interaction.post.reviews.create!(
        reviewer: reviewer, reviewed_user: reviewed, interaction: interaction,
        score: score, comment: comment
      )
    end

    add_message = lambda do |interaction:, user:, body:|
      return if interaction.messages.where(user_id: user.id, body: body).exists?
      interaction.messages.create!(user: user, body: body)
    end

    # Interactions completadas (transferencia real + reviews) ----------------
    puts "→ Interactions completadas con transferencia"
    completed_spec = [
      { post: "ana",    sender: "cami",   amount: 30, scores: [5, 5], comments: ["Quedó perfecto, gracias!", "Llegó puntual y muy maja"] },
      { post: "beto",   sender: "elsa",   amount: 25, scores: [5, 4], comments: ["El pan es una locura", "Excelente cliente"] },
      { post: "diego",  sender: "felipe", amount: 40, scores: [4, 5], comments: ["Bici quedó como nueva", "Pagó al toque"] },
      { post: "gaby",   sender: "ana",    amount: 30, scores: [5, 5], comments: ["Verduras impecables", "Encantadora"] },
      { post: "cami",   sender: "beto",   amount: 35, scores: [4, 4], comments: ["Llegó tibio pero rico", "Todo claro, sin dramas"] }
    ]
    completed_spec.each do |spec|
      post     = posts[spec[:post]]
      sender   = users[spec[:sender]]
      receiver = post.user
      i = upsert_interaction.call(post: post, sender: sender, receiver: receiver,
                                  status: :requested, agreed: spec[:amount])
      complete_with_transfer.call(interaction: i, amount: spec[:amount])
      add_review.call(interaction: i, reviewer: sender,   score: spec[:scores][0], comment: spec[:comments][0])
      add_review.call(interaction: i, reviewer: receiver, score: spec[:scores][1], comment: spec[:comments][1])
      puts "  ✓ @#{sender.username} → @#{receiver.username} (#{spec[:amount]}C, '#{post.title}')"
    end

    # Interactions abiertas en distintos estados -----------------------------
    puts "→ Interactions abiertas"
    open_spec = [
      { post: "felipe", sender: "hugo",   status: :requested,   amount: 60 },
      { post: "hugo",   sender: "diego",  status: :requested,   amount: 80 },
      { post: "ana",    sender: "julian", status: :negotiating, amount: 40 },
      { post: "beto",   sender: "ines",   status: :accepted,    amount: 30 },
      { post: "cami",   sender: "felipe", status: :in_progress, amount: 50 },
      { post: "julian", sender: "gaby",   status: :disputed,    amount: 25 },
      { post: "ines",   sender: "hugo",   status: :canceled,    amount: 30 }
    ]
    open_spec.each do |spec|
      post     = posts[spec[:post]]
      sender   = users[spec[:sender]]
      receiver = post.user
      i = upsert_interaction.call(post: post, sender: sender, receiver: receiver,
                                  status: :requested, agreed: spec[:amount])
      target = Interaction::STATUSES[spec[:status]]
      i.update_columns(status: target, agreed_credits: spec[:amount]) if i.status != spec[:status].to_s
      puts "  · @#{sender.username} → @#{receiver.username} [#{spec[:status]}] #{spec[:amount]}C en '#{post.title}'"
    end

    # Mensajes en chat (in_progress y disputed) ------------------------------
    puts "→ Chat"
    if (chat_i = Interaction.joins(:post).find_by(posts: { user_id: users["cami"].id }, sender_id: users["felipe"].id))
      add_message.call(interaction: chat_i, user: users["felipe"], body: "Hola Cami, te confirmo el pedido para las 13:00.")
      add_message.call(interaction: chat_i, user: users["cami"],   body: "Dale, ¿dirección y teléfono?")
      add_message.call(interaction: chat_i, user: users["felipe"], body: "Av. Apoquindo 1234, dpto 502. Tel +56 9 1234 5678.")
      add_message.call(interaction: chat_i, user: users["cami"],   body: "Anotado, salgo en 15 min.")
    end

    if (disp_i = Interaction.joins(:post).find_by(posts: { user_id: users["julian"].id }, sender_id: users["gaby"].id))
      add_message.call(interaction: disp_i, user: users["gaby"],   body: "Julian, el cel sigue con la misma falla. Quiero abrir disputa.")
      add_message.call(interaction: disp_i, user: users["julian"], body: "Gaby, traémelo de nuevo, lo reviso sin cargo.")
    end

    # Comentarios en posts ---------------------------------------------------
    puts "→ Comentarios"
    [
      { post: "ana",  user: "diego", body: "¿Atendés sábados por la tarde?" },
      { post: "ana",  user: "elsa",  body: "Recomendadísima, me cortó hace poco." },
      { post: "cami", user: "hugo",  body: "¿Llegás hasta San Miguel?" }
    ].each do |c|
      post = posts[c[:post]]
      user = users[c[:user]]
      next if post.comments.where(user_id: user.id, body: c[:body]).exists?
      post.comments.create!(user: user, body: c[:body])
    end

    # Recálculo de trust + nivel sincrónico ---------------------------------
    puts "→ Recalculando trust y nivel"
    users.each_value do |u|
      RecalculateUserTrustJob.perform_now(u.id)
      RecalculateUserLevelJob.perform_now(u.id)
    end

    puts ""
    puts "═══════════════════════════════════════════════════════"
    puts "  Demo lista. Login con cualquiera de:"
    users.each_value do |u|
      bal = u.credit_account&.reload&.cached_balance.to_i
      puts "    @#{u.username.ljust(7)} #{u.email_address.ljust(22)} L#{u.level} trust=#{u.trust_score} bal=#{bal}C"
    end
    puts "  Contraseña común: #{password}"
    puts "═══════════════════════════════════════════════════════"
    puts "  Σ ledger = #{Account.sum(:cached_balance)} (debe ser 0)"
  end

  desc "Borra usuarios demo (@ana, @beto, …) y todos sus posts/interactions/transferencias. Idempotente."
  task reset: :environment do
    unless Rails.env.development? || ENV["FORCE"] == "1"
      abort "demo:reset sólo corre en development. Para forzar: FORCE=1 bin/rails demo:reset"
    end

    demo_usernames = %w[ana beto cami diego elsa felipe gaby hugo ines julian]
    demo_users = User.where(username: demo_usernames)
    n = demo_users.count
    if n.zero?
      puts "No hay usuarios demo para borrar."
      next
    end

    # dependent: :destroy en User cubre posts, accounts, interactions, etc.
    # Pero credit_transactions tiene restrict_with_error sobre interaction —
    # borramos manualmente las transacciones primero.
    interaction_ids = Interaction.where("sender_id IN (?) OR receiver_id IN (?)",
                                        demo_users.select(:id), demo_users.select(:id)).pluck(:id)
    if interaction_ids.any?
      LedgerEntry.where(credit_transaction_id: CreditTransaction.where(interaction_id: interaction_ids)).delete_all
      CreditTransaction.where(interaction_id: interaction_ids).delete_all
    end

    demo_users.destroy_all
    puts "Borrados #{n} usuarios demo y sus dependencias."
    Rake::Task["credit:reconcile"].invoke
  end
end
