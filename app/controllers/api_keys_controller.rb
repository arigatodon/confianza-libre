# Claves de la API pública, gestionadas desde Ajustes. El token en texto plano
# viaja una sola vez en el flash de la redirección; después solo se ve el prefijo.
class ApiKeysController < ApplicationController
  before_action :set_api_key, only: :destroy

  def create
    _key, token = ApiKey.generate_for(Current.session.user, name: params.dig(:api_key, :name).to_s.strip.first(60))
    flash[:api_key_nueva] = token
    redirect_to settings_path(anchor: "api"), notice: "Clave creada. Cópiala ahora: no la volveremos a mostrar."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to settings_path(anchor: "api"), alert: "No pudimos crear la clave: #{e.record.errors.full_messages.to_sentence}"
  end

  def destroy
    @api_key.revoke!
    redirect_to settings_path(anchor: "api"), notice: "Clave revocada.", status: :see_other
  end

  private

  def set_api_key
    @api_key = Current.session.user.api_keys.find(params[:id])
  end
end
