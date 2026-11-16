class GeolocationsController < ApplicationController
  allow_unauthenticated_access only: :create
  skip_before_action :verify_authenticity_token, only: :create, if: -> { request.format.json? }

  COOKIE_NAME = :user_geo
  COOKIE_TTL  = 30.days

  def create
    lat = params[:latitude].to_f
    lng = params[:longitude].to_f

    if lat.zero? && lng.zero?
      head :unprocessable_entity and return
    end

    cookies.signed[COOKIE_NAME] = {
      value: { lat: lat, lng: lng, at: Time.current.to_i }.to_json,
      expires: COOKIE_TTL.from_now,
      same_site: :lax,
      httponly: true
    }

    if authenticated?
      user = Current.session.user
      user.update_columns(latitude: lat, longitude: lng) if user
    end

    head :no_content
  end
end
