# Clave para usar la API pública (/api/v1) en nombre de un usuario.
#
# El token en texto plano solo existe al crearla (se muestra una vez en
# Ajustes); en la base queda su SHA-256. Revocar = poner revoked_at; la fila
# se conserva para que el historial de "última vez usada" tenga sentido.
class ApiKey < ApplicationRecord
  PREFIJO = "cw_".freeze
  LARGO_VISIBLE = 11 # "cw_" + 8 caracteres, suficiente para distinguirlas

  belongs_to :user

  validates :name, presence: true, length: { maximum: 60 }
  validates :token_digest, presence: true, uniqueness: true
  validates :prefix, presence: true

  scope :active,  -> { where(revoked_at: nil) }
  scope :recent,  -> { order(created_at: :desc) }

  # Crea la clave y devuelve [registro, token en texto plano].
  def self.generate_for(user, name: "Mi web")
    token = PREFIJO + SecureRandom.base58(40)
    key = user.api_keys.create!(
      name:         name.presence || "Mi web",
      token_digest: digest(token),
      prefix:       token.first(LARGO_VISIBLE)
    )
    [ key, token ]
  end

  # Devuelve la clave activa que corresponde al token, o nil.
  def self.authenticate(token)
    return nil if token.blank? || !token.start_with?(PREFIJO)
    active.find_by(token_digest: digest(token))
  end

  def self.digest(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  def active? = revoked_at.nil?

  def revoke!
    update!(revoked_at: Time.current) if active?
  end

  # Marca de uso sin castigar cada request con un UPDATE: como mucho una vez
  # por hora.
  def touch_usage!
    return if last_used_at && last_used_at > 1.hour.ago
    update_column(:last_used_at, Time.current)
  end

  def masked
    "#{prefix}…"
  end
end
