class ReviewsController < ApplicationController
  before_action :set_post, only: :create

  def index
    @reviews = Review.includes(:reviewer, :reviewed_user, :post).order(created_at: :desc).limit(50)
  end

  def create
    interaction = @post.interactions.find_by(id: params.dig(:review, :interaction_id))
    return redirect_to(@post, alert: "Interacción inválida.") unless interaction

    reviewer = Current.session.user
    unless [ interaction.sender_id, interaction.receiver_id ].include?(reviewer.id)
      return redirect_to @post, alert: "No participaste de esta interacción."
    end

    reviewed_user = interaction.other_party(reviewer)

    @review = @post.reviews.build(review_params.merge(
      reviewer:      reviewer,
      reviewed_user: reviewed_user,
      interaction:   interaction
    ))

    if @review.save
      redirect_to @post, notice: "Evaluación enviada."
    else
      redirect_to @post, alert: @review.errors.full_messages.to_sentence
    end
  end

  private

  def set_post
    @post = Post.friendly.find(params[:post_id])
  end

  def review_params
    # No aceptamos category_weight desde el form — lo deriva el modelo desde
    # el rol del reviewer respecto al post (sender = proveedor, dueño = cliente).
    params.expect(review: [ :score, :comment, :interaction_id ])
  end
end
