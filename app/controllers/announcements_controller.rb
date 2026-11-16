class AnnouncementsController < ApplicationController
  # El blog del proyecto es público: el desarrollo se cuenta abierto.
  allow_unauthenticated_access only: %i[ index show ]
  before_action :require_admin,    only: %i[ new create edit update ]
  before_action :set_announcement, only: %i[ show edit update support ]

  def index
    @announcements = Announcement.published.includes(:user).recent
    @drafts        = admin? ? Announcement.where(published_at: nil).recent : Announcement.none

    respond_to do |format|
      format.html
      format.rss { @announcements = @announcements.limit(50) }
    end
  end

  def show
    # Los borradores sólo los ve quien publica.
    redirect_to announcements_path, alert: "Esa novedad todavía no está publicada." and return unless @announcement.published? || admin?
  end

  def new
    @announcement = Announcement.new(kind: params[:kind].presence || "cambio")
  end

  def create
    @announcement = Announcement.new(announcement_params.merge(user: Current.session.user))
    @announcement.published_at = Time.current if params[:publish].present?

    if @announcement.save
      redirect_to announcement_path(@announcement),
                  notice: @announcement.published? ? "Novedad publicada." : "Borrador guardado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @announcement.assign_attributes(announcement_params)
    @announcement.published_at ||= Time.current if params[:publish].present?

    if @announcement.save
      redirect_to announcement_path(@announcement),
                  notice: @announcement.published? ? "Novedad actualizada." : "Borrador guardado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Toggle de apoyo: señal liviana de la comunidad ("avancen por aquí").
  def support
    existing = @announcement.supports.find_by(user_id: Current.session.user_id)
    if existing
      existing.destroy
      notice = "Quitaste tu apoyo."
    else
      @announcement.supports.create(user_id: Current.session.user_id)
      notice = "Apoyo registrado. Gracias por marcar el rumbo."
    end
    redirect_to announcement_path(@announcement), notice: notice
  end

  private

  def set_announcement
    @announcement = Announcement.friendly.find(params[:slug])
  end

  def admin?
    authenticated? && Current.session.user.admin?
  end
  helper_method :admin?

  def require_admin
    redirect_to announcements_path, alert: "Sólo el equipo del proyecto publica novedades." unless admin?
  end

  def announcement_params
    permitted = params.expect(announcement: [ :title, :body, :kind ])
    # Un kind desconocido haría explotar el enum en la asignación.
    permitted[:kind] = "cambio" unless Announcement::KINDS.key?(permitted[:kind].to_s.to_sym)
    permitted
  end
end
