class NotificationsController < ApplicationController
  def index
    user = Current.session.user

    @notifications = user.notifications.includes(:actor, :notifiable).recent.limit(100)

    # Marcar todas como leídas al visitar el listado. update_all es eficiente
    # pero no dispara callbacks; el broadcast del badge lo hacemos a mano.
    if user.notifications.unread.update_all(read_at: Time.current).positive?
      Notification.refresh_badges_for(user)
    end
  end

  def show
    notification = Current.session.user.notifications.find(params[:id])
    notification.mark_as_read!
    redirect_to(notification.link_path || root_path)
  end
end
