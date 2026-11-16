class ExploreController < ApplicationController
  include Locatable
  allow_unauthenticated_access only: :index

  DEFAULT_RADIUS_KM = 50
  RADIUS_OPTIONS    = [ 1, 2, 5, 10, 25, 50, 100 ].freeze
  PAGE_LIMIT        = 60
  MIN_NEARBY        = 6

  def index
    radius = parsed_radius

    @filters = {
      q:           params[:q].to_s.strip.presence,
      category_id: params[:category_id].presence,
      kind:        params[:kind].presence,
      market:      params[:market].presence,
      radius_km:   radius,
      credits_max: params[:credits_max].presence
    }

    base = Post.visible
               .includes(:user, :category, media_attachments: :blob)
               .in_category(@filters[:category_id])
               .of_kind(@filters[:kind])
               .of_market(@filters[:market])
               .with_max_credits(@filters[:credits_max])

    # Con texto, la relevancia (ts_rank) manda y la distancia desempata; sin
    # texto, el orden es cercanía + recencia como siempre.
    searching = @filters[:q].present?
    base = base.search(@filters[:q]).with_pg_search_rank if searching

    if (coords = current_coordinates) && radius&.positive?
      @coords = coords
      scoped = base.near(coords, radius, units: :km)
      scoped = if searching
        scoped.reorder(Arel.sql("pg_search_rank DESC, distance ASC"))
      else
        scoped.reorder(Arel.sql("distance ASC, posts.created_at DESC"))
      end
      @posts = scoped.limit(PAGE_LIMIT)
    else
      @posts = if searching
        base.reorder(Arel.sql("pg_search_rank DESC, posts.created_at DESC")).limit(PAGE_LIMIT)
      else
        base.order(created_at: :desc).limit(PAGE_LIMIT)
      end
    end

    # Pocas publicaciones en el radio y sin filtros: completamos con lo más
    # reciente de toda la red en vez de mostrar un mapa casi vacío.
    @sin_filtros = @filters.except(:radius_km).values.all?(&:blank?)
    if @coords && @sin_filtros && @posts.size < MIN_NEARBY
      @more_posts = base.where.not(id: @posts.map(&:id)).order(created_at: :desc).limit(12)
    end

    # Búsqueda sin resultados: puente hacia publicar un pedido (Fase 2.2).
    @no_results_for_query = searching && @posts.empty?
    @geo_posts = @posts.select { |p| p.latitude && p.longitude }
    @categories = Category.where(publishable: true).order(:name)
  end

  private

  # Acepta 1/2/5/10/25/50/100 o nil (= "Todos", desactiva el filtro de radio).
  # Vacío o ausente cae al default. Valores fuera de la lista se ignoran.
  def parsed_radius
    raw = params[:radius_km]
    return DEFAULT_RADIUS_KM unless params.key?(:radius_km)
    return nil if raw.blank?  # explícito: "Todos"
    n = raw.to_i
    RADIUS_OPTIONS.include?(n) ? n : DEFAULT_RADIUS_KM
  end
end
