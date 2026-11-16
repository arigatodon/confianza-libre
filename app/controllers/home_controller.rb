class HomeController < ApplicationController
  include Locatable
  allow_unauthenticated_access only: [ :index, :how_it_works, :manifesto, :privacy, :api ]

  DEFAULT_RADIUS_KM = 25
  # Con menos publicaciones cercanas que esto, el feed se completa con lo más
  # reciente del resto del país: una red que recién parte no debe verse vacía.
  MIN_NEARBY = 6

  def index
    if authenticated?
      load_feed
      render :index
    else
      render :landing, layout: "marketing"
    end
  end

  def how_it_works
    render layout: "marketing"
  end

  def manifesto
    render layout: "marketing"
  end

  def privacy
    render layout: "marketing"
  end

  # Documentación de la API pública (publicar desde tu propia web).
  def api
    render layout: "marketing"
  end

  private

  def load_feed
    @market = params[:market].presence
    base = Post.visible.includes(:user, :category, media_attachments: :blob).of_market(@market)

    if (coords = current_coordinates)
      @coords = coords
      @recent_posts = base.near(coords, DEFAULT_RADIUS_KM, units: :km)
                          .reorder("distance ASC, posts.created_at DESC")
                          .limit(20)
      @feed_mode = :nearby
      if @recent_posts.size < MIN_NEARBY
        @more_posts = base.where.not(id: @recent_posts.map(&:id)).order(created_at: :desc).limit(12)
      end
    else
      @recent_posts = base.order(created_at: :desc).limit(20)
      @feed_mode = :recent
    end
  end
end
