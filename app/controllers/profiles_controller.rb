class ProfilesController < ApplicationController
  allow_unauthenticated_access only: [ :show, :qr ]

  def show
    @user = find_user
    @posts = @user.posts.visible.includes(:category, media_attachments: :blob).order(created_at: :desc).limit(30)

    # Sin sesión y sin vitrina: tarjeta mínima (avatar, username, verificación,
    # reputación resumida y publicaciones ya públicas). Lo personal — bio,
    # stats, padrino, avales — es para la comunidad, no para la web abierta.
    @full_view = @user.full_profile_visible_to?(authenticated? ? Current.session.user : nil)
    return unless @full_view

    @stats = {
      posts_count: @user.posts.visible.count,
      interactions_completed: @user.interactions_received.completed.count +
                              @user.interactions_sent.completed.count,
      reviews_received_count: @user.reviews_received.count,
      avg_score: @user.reviews_received.average(:score)&.to_f&.round(2)
    }

    # Reputación como proveedor: categorías publishable (servicios, productos,
    # delivery, etc.). Reputación como cliente: la categoría interna "Cliente"
    # — misma curva, otra narrativa.
    breakdown = Review.where(reviewed_user_id: @user.id)
                      .joins(:category)
                      .group("categories.name, categories.publishable")
                      .select("categories.name AS name, categories.publishable AS publishable, AVG(reviews.score) AS avg_score, COUNT(*) AS count")
                      .to_a

    @provider_breakdown = breakdown.select { |row| row.publishable }
                                    .sort_by { |r| -r.avg_score.to_f }
                                    .first(8)
    @client_breakdown   = breakdown.find    { |row| !row.publishable }

    # Padrinazgo: el sponsor es público (genera confianza ver de dónde viene
    # un nuevo usuario). La lista de ahijados sólo se muestra al dueño del
    # perfil — la cargamos siempre que el viewer sea el mismo user.
    @sponsor = @user.sponsor
    if authenticated? && Current.session.user_id == @user.id
      @sponsored = @user.sponsored_users.order(created_at: :desc).limit(50)
    end

    # Aval comunitario: cuántos vecinos lo avalan y si el viewer puede/ya lo hizo.
    @endorsements_count = @user.endorsements_received.count
    @recent_endorsers   = @user.endorsements_received.includes(:endorser)
                               .order(created_at: :desc).limit(5).map(&:endorser)
    if authenticated? && Current.session.user_id != @user.id
      viewer = Current.session.user
      @already_endorsed = @user.endorsements_received.exists?(endorser_id: viewer.id)
      @can_endorse      = viewer.moderator? && !@already_endorsed
    end
  end

  # Tarjeta QR imprimible de la vitrina: para pegar en el local o repartir.
  # El QR apunta al perfil público, así que la tarjeta también lo es.
  def qr
    user = find_user
    # El QR lleva utm para que /metricas cuente cuánta gente llega escaneando.
    png = Rails.cache.fetch([ "vitrina_qr", 2, user.id, user.updated_at ], expires_in: 1.day) do
      Vitrina::TarjetaQr.new(user, url: profile_url(user.username),
                             destino: profile_url(user.username, utm_source: "qr", utm_campaign: user.username)).render
    end
    expires_in 1.hour, public: true
    send_data png, type: "image/png", disposition: "inline", filename: "confianza-#{user.username}-qr.png"
  end

  private

  # Los slugs de FriendlyId son minúsculas ("boriscastillo") pero los links
  # usan el username tal cual ("BorisCastillo"): la búsqueda tiene que ser
  # insensible a mayúsculas para que confianza.world/BorisCastillo funcione.
  def find_user
    User.friendly.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    User.find_by!("LOWER(username) = ?", params[:id].to_s.downcase)
  end
end
