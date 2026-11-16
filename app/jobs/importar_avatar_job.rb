# Trae la foto de perfil que entrega el proveedor de acceso (Google) y la deja
# como avatar, solo si el usuario todavía no tiene uno. Si la descarga falla,
# no pasa nada: el avatar se puede subir a mano.
class ImportarAvatarJob < ApplicationJob
  queue_as :default

  def perform(user_id, url)
    user = User.find_by(id: user_id)
    return if user.nil? || user.avatar.attached? || url.blank?

    imagen = ImagenRemota.descargar(url)
    user.avatar.attach(io: imagen.io, filename: imagen.filename, content_type: imagen.content_type)
  rescue ImagenRemota::Error => e
    Rails.logger.info("[ImportarAvatarJob] user=#{user_id}: #{e.message}")
  end
end
