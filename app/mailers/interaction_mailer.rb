class InteractionMailer < ApplicationMailer
  # Aviso al receptor cuando alguien inicia una interacción con él.
  # Se dispara desde Interaction#notify_creation.
  def requested(interaction)
    @interaction = interaction
    @sender      = interaction.sender
    @post        = interaction.post
    mail subject: "@#{@sender.username} quiere interactuar contigo en Confianza",
         to: interaction.receiver.email_address
  end
end
