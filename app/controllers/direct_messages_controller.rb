class DirectMessagesController < ApplicationController
  before_action :set_conversation

  def create
    @message = @conversation.direct_messages.build(message_params.merge(user: Current.session.user))

    if @message.save
      respond_to do |format|
        # El broadcast del modelo ya appendea el mensaje; aquí sólo se resetea el form.
        format.turbo_stream { render :create }
        format.html { redirect_to conversation_path(@conversation) }
      end
    else
      redirect_to conversation_path(@conversation),
                  alert: @message.errors.full_messages.to_sentence
    end
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:conversation_id])
    return if @conversation.participant?(Current.session.user)

    redirect_to conversations_path, alert: "Esa conversación no es tuya."
  end

  def message_params
    params.expect(direct_message: [ :body ])
  end
end
