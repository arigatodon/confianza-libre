class EndorsementsController < ApplicationController
  rate_limit to: 20, within: 1.hour, only: :create,
             with: -> { redirect_back fallback_location: root_path, alert: "Demasiados avales seguidos, prueba más tarde." }

  def create
    endorsed    = User.find(params[:endorsed_id])
    endorsement = Endorsement.new(endorser: Current.session.user, endorsed: endorsed)

    if endorsement.save
      redirect_to profile_path(endorsed.username || endorsed.id),
                  notice: "Avalaste a @#{endorsed.username}. Tu palabra cuenta — gracias por hacer red."
    else
      redirect_to profile_path(endorsed.username || endorsed.id),
                  alert: endorsement.errors.full_messages.to_sentence
    end
  end
end
