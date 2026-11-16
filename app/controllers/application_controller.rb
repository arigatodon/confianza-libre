class ApplicationController < ActionController::Base
  include Authentication
  include RegistraVisitas
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :require_onboarding

  # Bots y escáneres piden páginas HTML como JSON/XML (`GET /` con
  # `Accept: application/json`, `/como-funciona.xml`…). Sin plantilla para
  # ese formato Rails lanza MissingTemplate → 500 → alerta por email. No es
  # un error nuestro: respondemos 406 y listo. Si el formato pedido sí es
  # HTML, la plantilla faltante es un bug real y debe seguir explotando.
  rescue_from ActionView::MissingTemplate do |error|
    raise error if request.format.html?
    head :not_acceptable
  end

  helper_method :unread_notifications_count

  def unread_notifications_count
    return 0 unless authenticated?
    @unread_notifications_count ||= Current.session.user.notifications.unread.count
  end

  private

  # Si el user tiene sesión activa y todavía no completó el tour de bienvenida,
  # redirige a /bienvenida. Excluye paths donde el redirect haría imposible
  # cerrar sesión / verificar email / volver a salir.
  def require_onboarding
    return unless authenticated?
    return if Current.session.user.onboarded?
    return if request.format != :html
    return if request.path.start_with?("/bienvenida", "/session", "/verificar-email", "/up")
    redirect_to onboarding_path
  end
end
