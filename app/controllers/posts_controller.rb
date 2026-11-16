class PostsController < ApplicationController
  allow_unauthenticated_access only: [ :index, :show, :tarjeta ]
  before_action :set_post, only: [ :show, :edit, :update, :destroy, :tarjeta ]
  before_action :require_owner!, only: [ :edit, :update, :destroy ]

  def index
    @posts = Post.visible.includes(:user, :category, media_attachments: :blob).order(created_at: :desc).limit(50)
  end

  def show
    @comments = @post.comments.visible.includes(:user).order(created_at: :asc).to_a
    @new_comment = @post.comments.build
    @review_pairs = review_pairs_for(@post)

    @pending_review_interactions = pending_review_interactions_for(Current.session&.user)
  end

  def new
    # Título prellenable desde el puente "publicar lo que busco" de /explore.
    prefill = params.fetch(:post, {}).permit(:title)
    @post = Current.session.user.posts.build(prefill.merge(kind: "venta"))
  end

  def create
    @post = Current.session.user.posts.build(post_params)
    if @post.save
      sync_media(@post)
      redirect_to @post, notice: "Publicación creada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @post.update(post_params)
      sync_media(@post)
      redirect_to @post, notice: "Publicación actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @post.destroy
    redirect_to posts_path, notice: "Publicación eliminada.", status: :see_other
  end

  # Tarjeta PNG del post para compartir en redes. También se usa como og:image,
  # así los links compartidos por WhatsApp/Telegram muestran una vista linda.
  def tarjeta
    head :not_found and return unless @post.published? && !@post.hidden_by_moderation?

    png = Rails.cache.fetch([ "tarjeta", @post.id, @post.updated_at ], expires_in: 1.day) do
      Difusion::Tarjeta.new(@post).render
    end
    expires_in 1.hour, public: true
    send_data png, type: "image/png", disposition: "inline"
  end

  private

  def set_post
    @post = Post.friendly.find(params[:id])
  end

  def require_owner!
    redirect_to root_path, alert: "No autorizado." unless @post.user_id == Current.session&.user_id
  end

  def post_params
    # OJO: `media` NO va aquí. has_many_attached reemplaza la colección al
    # asignar, así que mezclarlo en el mass-assign borraría los adjuntos
    # existentes al editar sin subir nada. Se maneja aparte en #sync_media.
    permitted = params.expect(post: [ :title, :description, :category_id, :latitude, :longitude,
                                      :kind, :pedido, :visibility_radius, :visibility_radius_km,
                                      :suggested_credits, :status, :difundir ])

    # El form usa km; el modelo guarda metros.
    if (km = permitted.delete(:visibility_radius_km)).present?
      permitted[:visibility_radius] = (km.to_f * 1000).to_i
    end

    # kind se deriva de la categoría en el modelo via before_validation,
    # así que no es necesario que venga del form.
    permitted
  end

  # Agrega los archivos nuevos sin tocar los existentes y purga sólo los que el
  # usuario marcó para quitar (remove_media[] = ids de attachment). Si no se
  # sube ni se marca nada, la multimedia actual queda intacta.
  def sync_media(post)
    remove_ids = Array(params[:remove_media]).reject(&:blank?)
    post.media_attachments.where(id: remove_ids).find_each(&:purge_later) if remove_ids.any?

    files = Array(params.dig(:post, :media)).reject(&:blank?)
    post.media.attach(files) if files.any?
  end

  # Reviews del post agrupadas por interaction. Para cada interaction:
  #   primary = review que recibió el dueño del post (la "review pública" del seller).
  #   counter = review que dio el dueño del post (su respuesta al otro).
  # Sólo se muestran interactions donde existe al menos la primary, para que la
  # sección de "Evaluaciones" sea siempre sobre la reputación del dueño.
  def review_pairs_for(post)
    reviews = post.reviews.includes(:reviewer, :reviewed_user).order(created_at: :desc)

    reviews.group_by(&:interaction_id).filter_map do |_, pair|
      primary = pair.find { |r| r.reviewed_user_id == post.user_id }
      counter = pair.find { |r| r.reviewer_id     == post.user_id }
      { primary: primary, counter: counter } if primary
    end
  end

  # Interactions completadas del post donde el usuario participó (como sender o
  # receiver) y todavía no dejó su review. Devuelve [] si no hay sesión.
  def pending_review_interactions_for(user)
    return [] unless user

    already_reviewed_ids = Review.where(reviewer_id: user.id).pluck(:interaction_id)

    @post.interactions.completed
         .where("sender_id = :u OR receiver_id = :u", u: user.id)
         .where.not(id: already_reviewed_ids)
         .includes(:sender, :receiver)
         .order(:created_at)
  end
end
