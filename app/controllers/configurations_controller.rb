# Path configuration para Hotwire Native (app Android, y a futuro iOS).
# La app la descarga al arrancar (con fallback al JSON empaquetado en sus
# assets) para decidir cómo presentar cada ruta: pantalla normal, modal, etc.
# Versionada en la URL (android_v1) para poder cambiar el formato sin romper
# apps viejas ya instaladas.
class ConfigurationsController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :require_onboarding

  def android_v1
    render json: {
      settings: {},
      rules: [
        {
          patterns: [ ".*" ],
          properties: {
            context: "default",
            uri: "hotwire://fragment/web",
            fallback_uri: "hotwire://fragment/web",
            pull_to_refresh_enabled: true
          }
        },
        {
          # Volver al inicio limpia el stack de navegación nativo
          patterns: [ "^$", "^/$" ],
          properties: { presentation: "clear_all" }
        },
        {
          # Formularios: modal nativo, sin pull-to-refresh (perderías lo escrito)
          patterns: [ "/new$", "/edit$" ],
          properties: { context: "modal", pull_to_refresh_enabled: false }
        },
        {
          # Mapa: el drag del mapa pelea con el gesto de pull-to-refresh
          patterns: [ "^/explore" ],
          properties: { pull_to_refresh_enabled: false }
        },
        {
          # Onboarding: pantalla completa sin refresh accidental
          patterns: [ "^/bienvenida" ],
          properties: { pull_to_refresh_enabled: false }
        }
      ]
    }
  end
end
