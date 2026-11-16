# Reporta por email los errores no manejados (excepciones que terminan en 500
# o jobs que explotan). Tope: 1 aviso por clase de error por hora vía cache,
# para que un crash-loop no inunde la casilla. Se suscribe sólo en producción
# (config/initializers/error_reporting.rb).
class ErrorEmailSubscriber
  THROTTLE = 1.hour

  # Errores de comandos operativos (los corre un humano por consola/deploy, no
  # el tráfico real): `bin/rails runner`, tareas rake y la consola. No son
  # incidentes de producción y no deben inundar la casilla de alertas.
  IGNORED_SOURCES = %w[
    application.runner.railties
    application.rake.railties
    application.console.railties
  ].freeze

  def initialize(cache: Rails.cache)
    @cache = cache
  end

  def report(error, handled:, severity:, context:, source: nil)
    return if handled
    return if IGNORED_SOURCES.include?(source)
    # write con unless_exist devuelve false si la key ya existía → throttled.
    return unless @cache.write("error-alert:#{error.class.name}", 1,
                               unless_exist: true, expires_in: THROTTLE)

    ErrorMailer.crash(
      error_class: error.class.name,
      message:     error.message.to_s.truncate(500),
      backtrace:   Array(error.backtrace).first(15).join("\n"),
      context:     "#{source} #{context.inspect}".truncate(800)
    ).deliver_later
  rescue => e
    # El reporte de errores jamás puede generar otro error visible.
    Rails.logger.error("[ErrorEmailSubscriber] no pude reportar: #{e.class} #{e.message}")
  end
end
