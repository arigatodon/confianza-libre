class PeopleController < ApplicationController
  # Directorio de vecinos. Sin sesión solo se ven las vitrinas (quienes
  # ELIGIERON ser encontrados desde afuera); con sesión, toda la comunidad.
  allow_unauthenticated_access only: :index

  def index
    @query = params[:q].to_s.strip
    scope  = User.where(status: :active).where.not(username: nil)
    scope  = scope.showcases unless authenticated?

    if @query.present?
      # Misma búsqueda full-text que los posts (usuario/titular/bio), tolerante
      # a acentos y tipeos. La relevancia manda; vitrina y verificación desempatan.
      scope = scope.full_text(@query.delete_prefix("@")).with_pg_search_rank
                   .reorder(Arel.sql("pg_search_rank DESC, showcase DESC, verification_level DESC"))
    else
      # Las vitrinas primero (son el escaparate del directorio), después los más
      # verificados y con mejor reputación.
      scope = scope.order(showcase: :desc, verification_level: :desc, trust_score: :desc, created_at: :asc)
    end

    @people = scope.limit(60).includes(avatar_attachment: :blob)
  end
end
