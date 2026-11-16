class RecalculateUserTrustJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    new_score = TrustScoreCalculator.call(user)
    user.update_column(:trust_score, new_score)

    # Un cambio de trust puede subir o bajar de nivel — encadenamos.
    RecalculateUserLevelJob.perform_later(user_id)
  end
end
