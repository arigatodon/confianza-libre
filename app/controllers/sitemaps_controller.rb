class SitemapsController < ApplicationController
  allow_unauthenticated_access only: :show
  # Skip onboarding redirect: el sitemap es para crawlers, no humanos logueados.
  skip_before_action :require_onboarding, raise: false

  def show
    @posts = Post.visible.order(updated_at: :desc).limit(5000)
    # Solo las vitrinas: los perfiles sin vitrina llevan noindex y no se listan.
    @users = User.showcases.where(status: :active).where.not(username: nil).order(updated_at: :desc).limit(5000)
    @territories = Territory.order(:name)
    @announcements = Announcement.published.order(published_at: :desc).limit(1000)
    respond_to do |format|
      format.xml
    end
  end
end
