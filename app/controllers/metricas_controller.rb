# Panel interno de uso (solo admins): visitas propias (PageView) + embudo de
# activación sacado de las tablas de negocio. Sin terceros ni cookies.
class MetricasController < ApplicationController
  before_action :require_admin

  DIAS = 30

  def show
    @desde = DIAS.days.ago.to_date
    vistas = PageView.between(@desde)

    @por_dia = vistas.group(:visited_on)
                     .pluck(:visited_on, Arel.sql("COUNT(*)"), Arel.sql("COUNT(DISTINCT visitor_digest)"))
                     .to_h { |dia, total, unicos| [ dia, { vistas: total, unicos: unicos } ] }
    @dias = (@desde..Date.current).to_a
    @max_unicos = [ @por_dia.values.map { _1[:unicos] }.max.to_i, 1 ].max

    @total_vistas = vistas.count
    @total_unicos = vistas.distinct.count(Arel.sql("visited_on::text || visitor_digest"))
    @vistas_app   = vistas.where(app: true).count

    @top_paginas = vistas.group(:path).count
                         .each_with_object(Hash.new(0)) { |(path, n), acc| acc[agrupar(path)] += n }
                         .sort_by { -_2 }.first(15)
    @top_referrers = vistas.where.not(referrer_host: nil).group(:referrer_host).count.sort_by { -_2 }.first(10)
    @top_utm = vistas.where.not(utm_source: nil).group(:utm_source, :utm_campaign).count.sort_by { -_2 }.first(10)

    @embudo = [ 7, 30 ].to_h do |d|
      desde = d.days.ago
      nuevos = User.where(created_at: desde..)
      [ d, {
        "Cuentas nuevas"         => nuevos.count,
        "Email verificado"       => nuevos.where.not(email_verified_at: nil).count,
        "Terminaron bienvenida"  => nuevos.where.not(onboarding_completed_at: nil).count,
        "Con vitrina pública"    => nuevos.where(showcase: true).count,
        "Publicaron algo"        => nuevos.joins(:posts).distinct.count,
        "Publicaciones (todas)"  => Post.where(created_at: desde..).count,
        "Interacciones (todas)"  => Interaction.where(created_at: desde..).count,
        "Usuarios que volvieron" => Session.where(updated_at: desde..).distinct.count(:user_id)
      } ]
    end
    @totales = {
      "Usuarios" => User.count, "Vitrinas públicas" => User.showcases.count,
      "Publicaciones" => Post.count, "Interacciones completadas" => Interaction.where(status: "completed").count
    }
  end

  private

  def require_admin
    redirect_to root_path, alert: "No tienes acceso a esa página." unless Current.session.user.admin?
  end

  RUTAS_FIJAS = %w[posts explore vecinos billetera logros novedades mensajes territorios settings signup
                   session bienvenida invita como-funciona economia manifiesto privacidad api interactions
                   notifications proposals alertas feedback moderacion metricas passwords].freeze

  # Junta las URLs con id/slug en su plantilla (/posts/:id, /:perfil…) para
  # que el ranking muestre secciones y no mil filas de una visita cada una.
  def agrupar(path)
    partes = path.split("/").reject(&:blank?)
    return "/" if partes.empty?
    if RUTAS_FIJAS.include?(partes.first)
      return "/#{partes.first}" if partes.size == 1
      # /bienvenida/vitrina, /session/new: palabras fijas, no ids.
      partes[1].match?(/\A[a-z-]+\z/) && !partes.first.in?(%w[posts territorios novedades]) ? "/#{partes.first(2).join("/")}" : "/#{partes.first}/:id"
    else
      partes.size > 1 ? "/:perfil/#{partes[1]}" : "/:perfil"
    end
  end
end
