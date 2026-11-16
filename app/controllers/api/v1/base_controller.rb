module Api
  module V1
    # Base de la API pública (JSON). Autenticación por API key del usuario
    # (Ajustes → Publicar desde tu web), enviada como
    #   Authorization: Bearer cw_...      o      X-Api-Key: cw_...
    #
    # Sin sesión ni CSRF: es para servidores de terceros (una función de
    # Netlify, un plugin de WordPress, un script), no para el navegador.
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods
      include ActionController::RateLimiting

      # Sin ParamsWrapper: envolvería el JSON bajo params[:post] dejando fuera
      # los campos que no son columnas (category, image_url…).
      wrap_parameters false

      before_action :authenticate_api_key!

      # Por clave: una integración ruidosa no afecta a las demás.
      rate_limit to: 300, within: 1.hour,
                 by: -> { @api_key&.id || request.remote_ip },
                 with: -> { render_error("Demasiadas solicitudes. Máximo 300 por hora.", :too_many_requests) }

      rescue_from ActiveRecord::RecordNotFound do
        render_error("No encontramos ese recurso.", :not_found)
      end

      rescue_from ActionController::ParameterMissing do |e|
        render_error("Falta el parámetro #{e.param}.", :bad_request)
      end

      private

      attr_reader :api_key

      def current_user = @api_key.user

      def authenticate_api_key!
        token = bearer_token || request.headers["X-Api-Key"]
        @api_key = ApiKey.authenticate(token)

        if @api_key.nil?
          return render_error("API key inválida o revocada. Crea una en confianza.world/settings.", :unauthorized)
        end

        user = @api_key.user
        unless user.active?
          return render_error("Tu cuenta no está activa.", :forbidden)
        end
        unless user.email_verified?
          return render_error("Verifica tu email en Confianza antes de usar la API.", :forbidden)
        end

        @api_key.touch_usage!
      end

      def bearer_token
        authenticate_with_http_token { |token, _options| token }
      end

      def render_error(mensaje, status, detalles: nil)
        cuerpo = { error: mensaje }
        cuerpo[:detalles] = detalles if detalles.present?
        render json: cuerpo, status: status
      end

      # Parámetros planos (sin envolver en "post"), como espera un cliente
      # JSON sencillo. También acepta el envoltorio por si alguien lo manda.
      def cuerpo
        params[:post].is_a?(ActionController::Parameters) ? params[:post] : params
      end
    end
  end
end
