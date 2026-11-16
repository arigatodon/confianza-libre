# Encuentra a quién avisar cuando se publica un post (Fase 2.2).
# Un pedido busca a quienes OFRECEN esa categoría cerca; una oferta busca a
# quienes PIDEN esa categoría cerca. En ambos casos: misma categoría, dentro
# del radio de aviso de cada candidato, excluyendo al propio autor.
class MatchFinder
  # Radio amplio para el primer filtro en SQL; el radio real de cada candidato
  # (su preferencia personal) se aplica después sobre la distancia calculada.
  MAX_RADIUS_KM = 100

  def initialize(post)
    @post = post
  end

  def candidates
    return [] unless @post.coordinates_present? && @post.category_id

    counterpart = @post.pedido? ? Post.offers : Post.pedidos
    nearby = counterpart.visible
                        .where(category_id: @post.category_id)
                        .where.not(user_id: @post.user_id)
                        .near([ @post.latitude, @post.longitude ], MAX_RADIUS_KM, units: :km)

    # Distancia (km) del post más cercano de cada autor al nuevo post.
    closest_km = {}
    nearby.each do |candidate_post|
      d = candidate_post.distance
      uid = candidate_post.user_id
      closest_km[uid] = d if closest_km[uid].nil? || d < closest_km[uid]
    end
    return [] if closest_km.empty?

    User.match_enabled.where(id: closest_km.keys).select do |user|
      user.wants_match_for?(@post.category_id) && closest_km[user.id] <= user.match_radius_km
    end
  end
end
