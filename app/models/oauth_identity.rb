# Vínculo entre un usuario y su cuenta en un proveedor externo (Google,
# Microsoft). `uid` es el identificador estable que entrega el proveedor
# (claim `sub`); el email se guarda solo como referencia para Ajustes.
class OauthIdentity < ApplicationRecord
  PROVIDERS = %w[google microsoft].freeze

  PROVIDER_LABELS_ES = {
    "google"    => "Google",
    "microsoft" => "Microsoft (Hotmail / Outlook)"
  }.freeze

  belongs_to :user

  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :uid, presence: true, uniqueness: { scope: :provider }

  def provider_label_es
    PROVIDER_LABELS_ES[provider] || provider.to_s.humanize
  end
end
