class PushSubscriptionsController < ApplicationController
  # El JS del push_controller manda la suscripción del navegador como JSON.
  def create
    subscription = PushSubscription.find_or_initialize_by(endpoint: subscription_params[:endpoint])
    subscription.user   = Current.session.user
    subscription.p256dh = subscription_params[:p256dh]
    subscription.auth   = subscription_params[:auth]

    if subscription.save
      head :created
    else
      head :unprocessable_entity
    end
  end

  private

  def subscription_params
    params.permit(:endpoint, :p256dh, :auth)
  end
end
