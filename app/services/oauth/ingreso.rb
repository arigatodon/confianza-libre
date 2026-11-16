module Oauth
  # Convierte un Perfil de un proveedor en un User con sesión posible:
  #
  #   1. si ya existe la identidad (provider, uid) → ese usuario;
  #   2. si no, pero hay un usuario con ese email verificado por el proveedor
  #      → se le vincula la identidad (así quien se registró con contraseña
  #      puede empezar a entrar con Google sin duplicar cuenta);
  #   3. si no → se crea el usuario, con el email ya verificado.
  #
  # Uso:
  #   resultado = Oauth::Ingreso.call(proveedor: "google", perfil: perfil, sponsor_code: "igor")
  #   resultado.ok? → resultado.user (y resultado.nuevo? si se acaba de crear)
  #   resultado.error → mensaje para el usuario
  class Ingreso
    Resultado = Struct.new(:user, :nuevo, :error, keyword_init: true) do
      def ok?    = user.present?
      def nuevo? = nuevo == true
    end

    def self.call(**) = new(**).call

    def initialize(proveedor:, perfil:, sponsor_code: nil)
      @proveedor    = proveedor.to_s
      @perfil       = perfil
      @sponsor_code = sponsor_code.to_s.strip.delete_prefix("@").presence
    end

    def call
      if (identidad = OauthIdentity.find_by(provider: @proveedor, uid: @perfil.uid))
        identidad.update(email: @perfil.email) if @perfil.email.present? && identidad.email != @perfil.email
        return Resultado.new(user: identidad.user)
      end

      return Resultado.new(error: "Tu cuenta de #{etiqueta} no compartió un email verificado. Regístrate con email y contraseña.") unless email_utilizable?

      User.transaction do
        if (existente = User.find_by(email_address: @perfil.email))
          vincular(existente)
          Resultado.new(user: existente)
        else
          nuevo = crear_usuario
          vincular(nuevo)
          Resultado.new(user: nuevo, nuevo: true)
        end
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn("[Oauth::Ingreso] #{@proveedor}: #{e.message}")
      Resultado.new(error: "No pudimos crear tu cuenta: #{e.record.errors.full_messages.to_sentence}")
    end

    private

    def etiqueta = OauthIdentity::PROVIDER_LABELS_ES[@proveedor] || @proveedor

    def email_utilizable?
      @perfil.email.present? && @perfil.email_verificado && @perfil.email.match?(URI::MailTo::EMAIL_REGEXP)
    end

    def vincular(user)
      user.oauth_identities.create!(provider: @proveedor, uid: @perfil.uid, email: @perfil.email)
    end

    def crear_usuario
      user = User.new(
        username:           username_libre,
        email_address:      @perfil.email,
        password:           SecureRandom.base58(32), # puede definir una propia vía "olvidé mi contraseña"
        email_verified_at:  Time.current,
        verification_level: :email
      )
      aplicar_padrino(user)
      user.save!

      # Lo mismo que hace User#mark_email_verified! al confirmar por link.
      RecalculateUserLevelJob.perform_later(user.id)
      WelcomeMailer.welcome(user).deliver_later
      ImportarAvatarJob.perform_later(user.id, @perfil.avatar_url) if @perfil.avatar_url.present?
      user
    end

    def aplicar_padrino(user)
      return unless @sponsor_code
      padrino = User.find_by("LOWER(username) = ?", @sponsor_code.downcase)
      return unless padrino
      user.sponsor = padrino
      user.sponsor_bonus_floor = EconomicParameter.get_int("sponsor_floor_boost", 5)
    end

    # Propone un username a partir del nombre (o del email) y le agrega un
    # número si ya está tomado. El usuario lo puede cambiar en Ajustes.
    def username_libre
      base = (@perfil.nombre.presence || @perfil.email.to_s.split("@").first.to_s)
      base = I18n.transliterate(base).downcase.gsub(/[^a-z0-9_]+/, "_").gsub(/\A_+|_+\z/, "")
      base = "vecino" if base.length < 3 || User::RESERVED_USERNAMES.include?(base)
      base = base.first(24)

      candidato = base
      sufijo = 1
      while User.where("LOWER(username) = ?", candidato).exists?
        sufijo += 1
        candidato = "#{base}#{sufijo}"
      end
      candidato
    end
  end
end
