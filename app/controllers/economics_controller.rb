class EconomicsController < ApplicationController
  # Página pública de transparencia: cualquiera puede auditar las reglas de la
  # economía (niveles, cupos, requisitos, quema, fondo territorial, decay) sin
  # necesidad de cuenta. Los datos se leen de las mismas fuentes que usa el
  # sistema en vivo (CreditLimitCalculator y EconomicParameter), nunca se
  # hardcodean: lo que se muestra es exactamente lo que se aplica.
  allow_unauthenticated_access only: :show

  def show
    @levels       = CreditLimitCalculator::LEVELS
    @requirements = CreditLimitCalculator::REQUIREMENTS

    # Categorías publicables con su multiplicador de cupo (excluye internas).
    @categories = Category.where(publishable: true).order(:max_credit_multiplier)

    # Parámetros vivos (mismos defaults que el resto del sistema).
    @burn_percent              = EconomicParameter.get_decimal("burn_percent", 2.0)
    @territory_percent         = EconomicParameter.get_decimal("territory_percent", 3.0)
    @min_burn_amount           = EconomicParameter.get_int("min_burn_amount", 1)
    @decay_check_days          = EconomicParameter.get_int("decay_check_days", 90)
    @decay_rate_per_run        = EconomicParameter.get_decimal("decay_rate_per_run", 0.05)
    @positive_review_threshold = EconomicParameter.get_int("positive_review_threshold", 4)

    # Si está logueado, resaltamos su nivel actual en la tabla.
    @current_level = authenticated? ? Current.session.user.level.to_i : nil
  end
end
