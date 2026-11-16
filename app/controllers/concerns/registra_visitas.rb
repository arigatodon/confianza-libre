# Registra cada página HTML servida con éxito en PageView (analítica propia).
# Nunca debe romper una respuesta: cualquier error se reporta y se ignora.
module RegistraVisitas
  extend ActiveSupport::Concern

  included do
    after_action :registrar_visita
  end

  private

  def registrar_visita
    return unless registrar_visita?

    PageView.insert({
      visited_on:     Date.current,
      path:           request.path.first(200),
      visitor_digest: PageView.digest_for(ip: request.remote_ip, user_agent: request.user_agent),
      logged_in:      resume_session.present?,
      referrer_host:  referrer_externo,
      utm_source:     params[:utm_source].presence&.to_s&.first(60),
      utm_campaign:   params[:utm_campaign].presence&.to_s&.first(60),
      app:            hotwire_native_app?,
      created_at:     Time.current
    })
  rescue => e
    Rails.error.report(e, handled: true)
  end

  def registrar_visita?
    request.get? && request.format.html? && response.status == 200 &&
      !turbo_frame_request? && !prefetch? && !PageView.bot?(request.user_agent)
  end

  # Turbo precarga los links al pasar el mouse: no es una visita.
  def prefetch?
    request.headers["X-Sec-Purpose"].to_s.include?("prefetch") ||
      request.headers["Sec-Purpose"].to_s.include?("prefetch")
  end

  def referrer_externo
    host = URI.parse(request.referer.to_s).host
    host if host.present? && host != request.host
  rescue URI::InvalidURIError
    nil
  end
end
