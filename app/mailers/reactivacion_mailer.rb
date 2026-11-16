# Correo personal de Igor a quien se registró y no volvió. Sin el layout de
# marca: la idea es que se lea (y se responda) como un mensaje de persona a
# persona. Se dispara a mano: bin/rails usuarios:reactivar.
class ReactivacionMailer < ApplicationMailer
  # A quién llegan las respuestas: CONTACTO_EMAIL, o la casilla de alertas.
  def self.reply_to_address = ENV["CONTACTO_EMAIL"].presence || ErrorMailer.alert_recipient

  layout false

  def vuelve(user)
    @user = user
    @publico = user.posts.visible.exists?
    mail to: user.email_address,
         from: "Igor de Confianza <no-reply@confianza.world>",
         reply_to: self.class.reply_to_address,
         subject: @publico ? "@#{user.username}, tu vitrina en Confianza ya está lista para compartir" :
                             "@#{user.username}, ¿te ayudo a armar tu vitrina en Confianza?"
  end
end
