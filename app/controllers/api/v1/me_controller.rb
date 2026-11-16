module Api
  module V1
    # GET /api/v1/me — para probar la clave y saber en nombre de quién publica.
    class MeController < BaseController
      def show
        user = current_user
        render json: {
          id:          user.id,
          username:    user.username,
          url:         profile_url(user),
          level:       user.level,
          trust_score: user.trust_score.to_f,
          api_key:     { name: api_key.name, prefix: api_key.masked }
        }
      end
    end
  end
end
