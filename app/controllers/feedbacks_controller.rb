class FeedbacksController < ApplicationController
  # Cualquier visitante puede mandar feedback (incluso sin loguearse,
  # para reportar bugs de login). Listar y resolver requiere ser
  # moderador (L3+).
  allow_unauthenticated_access only: [ :new, :create ]
  before_action :require_moderator!, only: [ :index, :show, :update ]

  def index
    scope = Feedback.includes(:user)
    @filter = params[:status].presence_in(Feedback::STATUSES.keys.map(&:to_s)) || "pending"
    @feedbacks = case @filter
                 when "all"       then scope.recent
                 when "unresolved" then scope.unresolved.recent
                 else scope.where(status: @filter).recent
                 end.limit(200)
    @counts = {
      "pending"    => Feedback.where(status: :pending).count,
      "read"       => Feedback.where(status: :read).count,
      "done"       => Feedback.where(status: :done).count,
      "archived"   => Feedback.where(status: :archived).count,
      "unresolved" => Feedback.unresolved.count,
      "all"        => Feedback.count
    }
  end

  def show
    @feedback = Feedback.find(params[:id])
    @feedback.update(status: :read) if @feedback.pending?
  end

  def new
    @feedback = Feedback.new(kind: params[:kind].presence_in(Feedback::KINDS.keys.map(&:to_s)) || "idea")
  end

  def create
    @feedback = Feedback.new(feedback_params)
    @feedback.user = Current.session&.user
    @feedback.url        = params.dig(:feedback, :url).to_s.first(500).presence
    @feedback.user_agent = request.user_agent.to_s.first(500).presence

    if @feedback.save
      redirect_to root_path, notice: "Gracias, leemos cada feedback."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @feedback = Feedback.find(params[:id])
    new_status = params[:status].to_s
    if Feedback::STATUSES.key?(new_status.to_sym)
      @feedback.update(status: new_status)
      redirect_to feedbacks_path, notice: "Feedback marcado como #{Feedback::STATUS_LABELS_ES[new_status]&.downcase}."
    else
      redirect_to feedbacks_path, alert: "Estado inválido."
    end
  end

  private

  def feedback_params
    params.expect(feedback: [ :kind, :body ])
  end

  def require_moderator!
    unless authenticated? && Current.session.user.moderator?
      redirect_to root_path, alert: "Sólo moderadores."
    end
  end
end
