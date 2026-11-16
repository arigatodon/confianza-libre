class RecalculateUserLevelJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    new_limits = CreditLimitCalculator.call(user)
    previous_level = user.level
    user.update_columns(new_limits)

    # update_columns skipea callbacks. Si el nivel cambió, refrescamos la
    # wallet del user en vivo (el nivel y los rangos cambian visualmente).
    if previous_level != new_limits[:level]
      Turbo::StreamsChannel.broadcast_refresh_later_to(user, :wallet)
    end
  end
end
