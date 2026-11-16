module Locatable
  extend ActiveSupport::Concern

  COOKIE = :user_geo

  private

  # Devuelve [lat, lng] o nil si todavía no conocemos la ubicación del visitante.
  # Prioridad: cookie firmada → usuario autenticado.
  def current_coordinates
    if (raw = cookies.signed[COOKIE]).present?
      parsed = JSON.parse(raw) rescue nil
      if parsed && parsed["lat"] && parsed["lng"]
        return [ parsed["lat"].to_f, parsed["lng"].to_f ]
      end
    end

    if authenticated? && (u = Current.session&.user) && u.latitude && u.longitude
      return [ u.latitude, u.longitude ]
    end

    nil
  end

  def current_coordinates?
    current_coordinates.present?
  end
end
