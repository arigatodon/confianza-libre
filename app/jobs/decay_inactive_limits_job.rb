class DecayInactiveLimitsJob < ApplicationJob
  queue_as :default

  # Si un usuario está en saldo negativo y no recibió reviews positivas
  # recientes, su credit_floor decrece para que no pueda profundizar más la
  # deuda. ECONOMIA.md § 6 / § 4.7.
  #
  # Parámetros tunables vía economic_parameters:
  #   decay_check_days          → ventana sin reviews positivas (default 90)
  #   decay_rate_per_run        → reducción porcentual por corrida (default 0.05)
  #   positive_review_threshold → score mínimo que cuenta como "positiva" (default 4)
  #
  # No baja credit_floor por debajo de |cached_balance|: no condonamos deuda,
  # sólo cerramos el grifo para no profundizarla.

  def perform
    threshold_days = EconomicParameter.get_int("decay_check_days", 90)
    rate           = EconomicParameter.get_decimal("decay_rate_per_run", 0.05)
    positive_min   = EconomicParameter.get_int("positive_review_threshold", 4)
    cutoff         = threshold_days.days.ago

    decayed = 0

    self.class.candidates(positive_min, cutoff).find_each do |user|
      decayed += 1 if apply_decay!(user, user.credit_account, rate)
    end

    Rails.logger.info("[DecayInactiveLimitsJob] usuarios afectados: #{decayed}")
    decayed
  end

  # Filtra candidatos en SQL en vez de recorrer todos los users en Ruby:
  # solo cuentas en negativo, con floor > 0 y sin review positiva reciente.
  def self.candidates(positive_min, cutoff)
    User.where(credit_floor: 1..)
        .joins(:credit_account)
        .where(accounts: { cached_balance: ...0 })
        .where.not(
          id: Review.where(score: positive_min.., created_at: cutoff..)
                    .select(:reviewed_user_id)
        )
        .includes(:credit_account)
  end

  private

  def apply_decay!(user, account, rate)
    decayed = (user.credit_floor * (1.0 - rate)).floor
    min_allowed = account.cached_balance.abs
    new_floor   = [ decayed, min_allowed ].max

    return false if new_floor == user.credit_floor
    user.update_column(:credit_floor, new_floor)
    true
  end
end
