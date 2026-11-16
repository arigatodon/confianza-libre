class NewsMailer < ApplicationMailer
  # Digest de novedades para la base existente. Se dispara a mano con la
  # rake task novedades:digest (no es automático: cada envío se decide).
  def novedades_digest(user)
    @user = user
    mail subject: "Tus publicaciones ahora viajan más lejos 📣 nuevo canal y difusión con tu permiso",
         to: user.email_address
  end

  # Variante para cuentas sin verificar: las mismas novedades, pero abriendo
  # con el link de verificación (lo único que los separa de usar la red).
  def novedades_verifica(user)
    @user  = user
    @token = user.generate_token_for(:email_verification)
    mail subject: "Tu cuenta en Confianza está a un clic — y la red se renovó ✅",
         to: user.email_address
  end
end
