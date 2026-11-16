class NotificationCreator
  # No notifica si recipient es nil o si recipient == actor (no avisar de
  # tus propias acciones).
  def self.call(recipient:, notifiable:, kind:, body:, actor: nil)
    return if recipient.nil?
    return if actor && recipient.id == actor.id

    Notification.create!(
      recipient:   recipient,
      actor:       actor,
      notifiable:  notifiable,
      kind:        kind,
      body:        body
    )
  end
end
