# Alerta guardada (Fase 2.3): una búsqueda de /explore que el usuario guarda
# para que la red le avise cuando aparece un post nuevo que la cumple.
class SavedSearch < ApplicationRecord
  MAX_PER_USER = 10

  belongs_to :user
  belongs_to :category, optional: true

  validate :within_user_limit, on: :create

  scope :recent, -> { order(created_at: :desc) }

  # ¿El post recién publicado cumple todos los criterios de esta alerta?
  def matches?(post)
    category_matches?(post) &&
      kind_matches?(post) &&
      market_matches?(post) &&
      credits_match?(post) &&
      within_radius?(post) &&
      query_matches?(post)
  end

  def centered?
    latitude.present? && longitude.present?
  end

  # Resumen legible para el listado en /settings.
  def summary
    parts = []
    parts << "«#{query}»" if query.present?
    parts << category.name if category
    parts << Post::KIND_LABELS_ES[kind] if kind.present?
    parts << market.capitalize if market.present?
    parts << "≤ #{credits_max} C" if credits_max.present?
    parts << "#{radius_km} km" if radius_km.present? && centered?
    parts.presence&.join(" · ") || "Todas las publicaciones nuevas"
  end

  private

  def category_matches?(post)
    category_id.nil? || category_id == post.category_id
  end

  def kind_matches?(post)
    kind.blank? || kind == post.kind
  end

  def market_matches?(post)
    case market
    when "ofertas" then !post.pedido?
    when "pedidos" then post.pedido?
    else true
    end
  end

  def credits_match?(post)
    credits_max.blank? || post.suggested_credits.nil? || post.suggested_credits <= credits_max
  end

  def within_radius?(post)
    return true if radius_km.blank? || !centered?
    return false unless post.coordinates_present?

    km = Geocoder::Calculations.distance_between(
      [ latitude, longitude ], [ post.latitude, post.longitude ], units: :km
    )
    km <= radius_km
  end

  def query_matches?(post)
    return true if query.blank?
    Post.where(id: post.id).search(query).exists?
  end

  def within_user_limit
    return if user.nil?
    if user.saved_searches.count >= MAX_PER_USER
      errors.add(:base, "Llegaste al máximo de #{MAX_PER_USER} alertas. Borra alguna para crear otra.")
    end
  end
end
