class TypingChannel < ApplicationCable::Channel
  # Indicador "X está escribiendo…" en el chat de una Interaction.
  # No persiste nada — sólo retransmite eventos entre los dos participantes.
  #
  # Cliente suscribe: { channel: "TypingChannel", interaction_id: 42 }
  # Cliente envía:    perform("start") / perform("stop")
  # Otros viewers reciben: { event: "start"|"stop", user_id:, username: }
  def subscribed
    interaction = Interaction.find_by(id: params[:interaction_id])
    return reject unless interaction && participant?(interaction)

    @interaction_id = interaction.id
    stream_from stream_name
  end

  def start
    broadcast_event("start")
  end

  def stop
    broadcast_event("stop")
  end

  private

  def participant?(interaction)
    [ interaction.sender_id, interaction.receiver_id ].include?(current_user&.id)
  end

  def stream_name
    "typing:interaction:#{@interaction_id}"
  end

  def broadcast_event(event)
    return unless @interaction_id && current_user
    ActionCable.server.broadcast(stream_name, {
      event:    event,
      user_id:  current_user.id,
      username: current_user.username
    })
  end
end
