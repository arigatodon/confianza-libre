class SavedSearchesController < ApplicationController
  include Locatable

  def create
    coords = current_coordinates
    search = Current.session.user.saved_searches.new(
      query:       params[:q].to_s.strip.presence,
      category_id: params[:category_id].presence,
      kind:        params[:kind].presence,
      market:      params[:market].presence,
      credits_max: params[:credits_max].presence,
      radius_km:   params[:radius_km].presence,
      latitude:    coords&.first,
      longitude:   coords&.last
    )

    if search.save
      redirect_back fallback_location: explore_path, notice: "Alerta guardada. Te avisaremos cuando aparezca algo así."
    else
      redirect_back fallback_location: explore_path, alert: search.errors.full_messages.to_sentence
    end
  end

  def destroy
    search = Current.session.user.saved_searches.find(params[:id])
    search.destroy
    redirect_back fallback_location: settings_path, notice: "Alerta eliminada."
  end
end
