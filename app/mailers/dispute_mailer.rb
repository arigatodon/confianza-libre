class DisputeMailer < ApplicationMailer
  # Aviso a la contraparte cuando alguien abre una disputa sobre la
  # interacción que comparten. Se dispara desde Dispute#notify_opened.
  def opened(dispute)
    @dispute     = dispute
    @interaction = dispute.interaction
    @opener      = dispute.opener
    recipient    = dispute.counterpart
    return unless recipient

    mail subject: "@#{@opener.username} abrió una disputa en Confianza",
         to: recipient.email_address
  end

  # Aviso a quien abrió la disputa cuando la contraparte responde.
  def responded(dispute)
    @dispute     = dispute
    @interaction = dispute.interaction
    @counterpart = dispute.counterpart

    mail subject: "@#{@counterpart.username} respondió tu disputa en Confianza",
         to: dispute.opener.email_address
  end

  # Aviso del veredicto a cada parte. Se dispara desde DisputeResolver.
  def resolved(dispute, recipient)
    @dispute     = dispute
    @interaction = dispute.interaction
    @recipient   = recipient

    mail subject: "Se resolvió tu disputa en Confianza",
         to: recipient.email_address
  end
end
