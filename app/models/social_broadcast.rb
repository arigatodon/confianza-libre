# Registro de cada envío de un post a una red social externa.
# La fila se crea al intentar el envío; el índice único (post_id, network)
# garantiza que un post nunca se publique dos veces en la misma red.
class SocialBroadcast < ApplicationRecord
  STATUSES = %w[pendiente enviado error].freeze

  belongs_to :post

  validates :network, presence: true
  validates :status,  inclusion: { in: STATUSES }

  scope :enviados, -> { where(status: "enviado") }

  def marcar_enviado!(external_id)
    update!(status: "enviado", external_id: external_id, sent_at: Time.current, error_message: nil)
  end

  def marcar_error!(mensaje)
    update!(status: "error", error_message: mensaje.to_s.truncate(255))
  end
end
