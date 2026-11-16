class UsersController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to new_user_path, alert: "Demasiados intentos, prueba en unos minutos." }

  before_action :set_current_user, only: %i[ edit update ]

  def new
    @user = User.new
    # Llegada por link de invitación (/invita/:code): prellenamos el padrino.
    @sponsor_code = params[:code].to_s.strip.delete_prefix("@").presence
    # Si en vez del formulario elige Google/Microsoft, el padrino no se pierde.
    session[:sponsor_code] = @sponsor_code if @sponsor_code
  end

  def create
    sponsor_code = params.dig(:user, :sponsor_code).to_s.strip.delete_prefix("@")
    @user = User.new(user_params_for_create)
    apply_sponsor(@user, sponsor_code) if sponsor_code.present?

    if @user.errors.empty? && @user.save
      start_new_session_for @user
      redirect_to root_path, notice: "Bienvenido a Confianza, @#{@user.username}."
    else
      @sponsor_code = sponsor_code  # repoblamos el campo en el form
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_settings_sections
  end

  def update
    if @user.update(user_params_for_update)
      redirect_to settings_path, notice: "Perfil actualizado."
    else
      # La vista edit necesita sus secciones también al re-renderizar con errores.
      load_settings_sections
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_current_user
    @user = Current.session.user
  end

  def load_settings_sections
    @identity_verification = @user.identity_verifications.recent.first
    @saved_searches = @user.saved_searches.recent.includes(:category)
    @api_keys = @user.api_keys.active.recent
    @oauth_identities = @user.oauth_identities.order(:provider)
  end

  def user_params_for_create
    params.expect(user: [ :email_address, :username, :password, :password_confirmation, :bio, :avatar ])
  end

  # sponsor_code = username del padrino. Si la búsqueda falla, anotamos
  # un error en el modelo (no en una key del params) para que el form
  # pueda mostrarlo en la lista de errores.
  def apply_sponsor(user, code)
    sponsor = User.find_by("LOWER(username) = ?", code.downcase)
    if sponsor.nil?
      user.errors.add(:base, "no encontramos a tu padrino @#{code}")
      return
    end
    user.sponsor = sponsor
    user.sponsor_bonus_floor = EconomicParameter.get_int("sponsor_floor_boost", 5)
  end

  # En la edición, si password viene en blanco no lo tocamos.
  def user_params_for_update
    permitted = params.expect(user: [ :email_address, :username, :bio,
                                      :headline, :showcase,
                                      :vitrina_plantilla, :accent_color, :whatsapp,
                                      :horario, :portada,
                                      :link_instagram, :link_facebook, :link_web,
                                      :match_notifications, :match_radius_km,
                                      { match_category_ids: [] },
                                      :password, :password_confirmation, :avatar ])
    # Checkboxes de categorías: quitar el "" que Rails agrega para permitir
    # deseleccionar todo, y quedarnos con ids enteros.
    if permitted[:match_category_ids]
      permitted[:match_category_ids] = permitted[:match_category_ids].reject(&:blank?).map(&:to_i)
    end
    if permitted[:password].blank?
      permitted = permitted.except(:password, :password_confirmation)
    end
    permitted
  end
end
