class MessagesController < ApplicationController
  before_action :set_interaction
  before_action :ensure_participant!

  def create
    @message = @interaction.messages.build(message_params.merge(user: Current.session.user))

    if @message.save
      respond_to do |format|
        # El broadcast (Message.broadcasts_to) ya se encargó de appender el
        # mensaje en el DOM de cualquier viewer suscrito — incluido este.
        # Acá sólo limpiamos el form del sender.
        format.turbo_stream { render :create }
        format.html { redirect_to interaction_path(@interaction) }
      end
    else
      redirect_to interaction_path(@interaction),
                  alert: @message.errors.full_messages.to_sentence
    end
  end

  private

  def set_interaction
    @interaction = Interaction.find(params[:interaction_id])
  end

  def ensure_participant!
    user = Current.session.user
    return if [ @interaction.sender_id, @interaction.receiver_id ].include?(user.id)
    redirect_to root_path, alert: "No autorizado."
  end

  def message_params
    params.expect(message: [ :body ])
  end
end
