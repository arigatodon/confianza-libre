class OnboardingController < ApplicationController
  skip_before_action :require_onboarding

  TOTAL_STEPS = 7

  def show
    @step = params[:step].to_i
    @step = 1 if @step < 1 || @step > TOTAL_STEPS
    @total = TOTAL_STEPS
  end

  def complete
    Current.session.user.complete_onboarding!
    redirect_to siguiente_paso, notice: "¡Listo! Ya sabes cómo funciona Confianza."
  end

  def skip
    Current.session.user.complete_onboarding!
    redirect_to siguiente_paso, notice: "Listo. Puedes repetir el tour desde Ajustes."
  end

  # Paso "Crea tu vitrina": lo mínimo para que el perfil sirva como
  # link-in-bio desde el primer día, aunque todavía no haya vecinos cerca.
  def vitrina
    @user = Current.session.user
  end

  def guardar_vitrina
    @user = Current.session.user
    if @user.update(vitrina_params.merge(showcase: params.dig(:user, :showcase) == "1"))
      @user.complete_onboarding!
      redirect_to profile_path(@user.username, vitrina_nueva: 1),
                  notice: @user.showcase? ? "¡Tu vitrina está publicada! Compártela." : "Guardamos tu perfil."
    else
      render :vitrina, status: :unprocessable_entity
    end
  end

  private

  # Quien ya tiene vitrina pública no necesita el paso; el resto pasa por ahí.
  def siguiente_paso
    Current.session.user.showcase? ? explore_path : onboarding_vitrina_path
  end

  def vitrina_params
    params.expect(user: [ :headline, :vitrina_plantilla, :whatsapp, :horario, :avatar ])
  end
end
