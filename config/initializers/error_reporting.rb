# Errores no manejados → email al equipo (ver ErrorEmailSubscriber).
# Sólo producción: en dev/test el error se ve en la consola y la suite.
Rails.application.config.after_initialize do
  Rails.error.subscribe(ErrorEmailSubscriber.new) if Rails.env.production?
end
