class TrustScoreCalculator
  # Computa el trust_score de un usuario como avg ponderado de las reviews
  # recibidas:
  #
  #   Σ (score × category_weight) / Σ category_weight
  #
  # category_weight viene snapshotead0 en la review desde la categoría del post
  # al momento de la evaluación — así futuros cambios en Category.trust_weight
  # no reescriben la historia.
  #
  # Si todavía no hay MIN_DISTINCT_REVIEWERS reviewers distintos, el score
  # vale el default neutral (ECONOMIA.md § 6: evita reputación amplificada
  # por una sola contraparte).

  NEUTRAL_DEFAULT        = 3.0
  MIN_DISTINCT_REVIEWERS = 3

  def self.call(user)
    new(user).call
  end

  def initialize(user)
    @user = user
  end

  def call
    reviews = @user.reviews_received
    distinct = reviews.distinct.count(:reviewer_id)
    return NEUTRAL_DEFAULT if distinct < MIN_DISTINCT_REVIEWERS

    sum_weighted = reviews.sum("score * category_weight").to_f
    sum_weights  = reviews.sum(:category_weight).to_f
    return NEUTRAL_DEFAULT if sum_weights.zero?

    (sum_weighted / sum_weights).round(2)
  end
end
