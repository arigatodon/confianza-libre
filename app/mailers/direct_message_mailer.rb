class DirectMessageMailer < ApplicationMailer
  # Aviso por correo de un mensaje directo nuevo. El throttle (1 correo por
  # conversación cada 12 h) vive en DirectMessage#email_recipient.
  def new_message(direct_message)
    @message   = direct_message
    @sender    = direct_message.user
    @recipient = direct_message.conversation.other_party(@sender)

    mail subject: "@#{@sender.username} te escribió en Confianza",
         to: @recipient.email_address
  end
end
