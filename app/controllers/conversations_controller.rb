class ConversationsController < ApplicationController
  before_action :set_conversation, only: :show

  def index
    @conversations = Conversation.involving(Current.session.user)
                                 .includes(:participant_a, :participant_b)
                                 .by_recency.limit(100)
  end

  def show
    @messages = @conversation.direct_messages.visible.ordered.includes(:user).last(200)
    @other    = @conversation.other_party(Current.session.user)

    # Entrar al chat marca como leídas las notificaciones de esta conversación.
    user = Current.session.user
    if user.notifications.unread.where(notifiable: @conversation).update_all(read_at: Time.current).positive?
      Notification.refresh_badges_for(user)
    end
  end

  # POST /mensajes (user_id) — abre (o retoma) la conversación con esa persona.
  def create
    other = User.find(params[:user_id])
    if other.id == Current.session.user_id
      return redirect_back fallback_location: root_path, alert: "No puedes conversar contigo mismo."
    end

    conversation = Conversation.between!(Current.session.user, other)
    redirect_to conversation_path(conversation)
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:id])
    return if @conversation.participant?(Current.session.user)

    redirect_to conversations_path, alert: "Esa conversación no es tuya."
  end
end
