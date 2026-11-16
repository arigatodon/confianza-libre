Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resources :users, only: [ :new, :create ]
  get "signup", to: "users#new", as: :signup
  # Link de invitación compartible: /invita/igor → signup con padrino prellenado.
  get "invita/:code", to: "users#new", as: :invite

  get   "settings", to: "users#edit",   as: :settings
  patch "settings", to: "users#update"
  put   "settings", to: "users#update"

  resources :posts do
    get :tarjeta, on: :member, defaults: { format: :png }
    resources :interactions, only: [ :create ]
    resources :reviews, only: [ :create ]
    resources :comments, only: [ :create, :destroy ]
  end
  resources :interactions, only: [ :index, :show ] do
    member do
      patch :accept
      patch :counter
      patch :start
      patch :confirm
      patch :cancel
      patch :dispute
      patch :respond_dispute
    end
    resources :messages, only: [ :create ]
  end
  resources :reviews, only: [ :index ]

  post "geolocation", to: "geolocations#create"

  get "explore", to: "explore#index"
  # El resto de las rutas están en español: /explorar es lo que la gente escribe.
  get "explorar", to: redirect { |_, req| "/explore#{"?#{req.query_string}" if req.query_string.present?}" }
  get "vecinos", to: "people#index", as: :people

  get "billetera", to: "wallet#show", as: :wallet
  get "logros",    to: "achievements#index", as: :achievements

  get  "verificar-email/:token", to: "email_verifications#show",   as: :email_verification
  post "verificar-email",        to: "email_verifications#create", as: :resend_email_verification

  get "ledger/audit", to: "ledger#audit", as: :ledger_audit

  resources :territories, only: [ :index, :show ], path: "territorios", param: :slug do
    resources :proposals, only: [ :create ], shallow: false
  end
  resources :proposals, only: [ :show ] do
    member do
      patch :vote
      patch :execute
      patch :cancel
    end
  end

  resources :notifications, only: [ :index, :show ]

  get   "bienvenida",           to: "onboarding#show",     as: :onboarding
  post  "bienvenida/completar", to: "onboarding#complete", as: :complete_onboarding
  post  "bienvenida/saltar",    to: "onboarding#skip",     as: :skip_onboarding
  get   "bienvenida/vitrina",   to: "onboarding#vitrina",  as: :onboarding_vitrina
  patch "bienvenida/vitrina",   to: "onboarding#guardar_vitrina"

  # PWA + notificaciones push
  get "service-worker", to: "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest",       to: "rails/pwa#manifest",       as: :pwa_manifest
  resources :push_subscriptions, only: [ :create ]

  # Mensajes directos (fuera de interacciones)
  resources :conversations, path: "mensajes", only: [ :index, :show, :create ] do
    resources :direct_messages, only: [ :create ]
  end

  resources :endorsements, only: [ :create ]
  resources :reports, only: [ :new, :create ]
  resources :feedbacks, path: "feedback", only: [ :new, :create, :index, :show, :update ]
  get   "moderacion",     to: "moderation#index", as: :moderation
  get   "moderacion/:id", to: "moderation#show",  as: :moderation_report
  patch "moderacion/:id", to: "moderation#resolve", as: :resolve_moderation_report

  get   "moderacion/disputas/:id", to: "moderation#show_dispute",    as: :moderation_dispute
  patch "moderacion/disputas/:id", to: "moderation#resolve_dispute", as: :resolve_moderation_dispute

  # Verificación de identidad: el usuario sube el documento; el moderador la
  # revisa y sirve la imagen sólo a L3+ (nunca por URL pública de ActiveStorage).
  resource :identity_verification, only: [ :create ], path: "identidad"

  # Alertas guardadas: se crean desde /explore, se listan/borran en /settings.
  resources :saved_searches, only: [ :create, :destroy ], path: "alertas"
  patch "moderacion/identidad/:id", to: "moderation#resolve_identity", as: :resolve_moderation_identity
  get   "moderacion/identidad/:id/documento/:doc_id",
        to: "moderation#identity_document", as: :moderation_identity_document

  # Entrar / crear cuenta con Google o Microsoft (Hotmail, Outlook). Cada
  # proveedor aparece en los formularios solo si tiene sus credenciales.
  get "auth/:provider",          to: "oauth_sessions#new",    as: :oauth_start,
      constraints: { provider: /google|microsoft/ }
  get "auth/:provider/callback", to: "oauth_sessions#create", as: :oauth_callback,
      constraints: { provider: /google|microsoft/ }

  # API pública: publicar en Confianza desde un sitio propio con una API key
  # (se crean en /settings). Docs humanas en /api.
  resources :api_keys, only: [ :create, :destroy ], path: "ajustes/api-keys"
  get "api", to: "home#api", as: :api_docs
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      resource  :me,    only: :show, controller: "me"
      resources :posts, only: [ :index, :show, :create, :update, :destroy ]
    end
  end

  get "como-funciona", to: "home#how_it_works", as: :how_it_works
  get "economia",      to: "economics#show",    as: :economics
  get "manifiesto",    to: "home#manifesto",    as: :manifesto
  get "privacidad",    to: "home#privacy",      as: :privacy

  # Novedades: blog abierto del proyecto (cambios, versiones, consultas).
  resources :announcements, only: [ :index, :show, :new, :create, :edit, :update ],
            path: "novedades", param: :slug do
    member { post :support }
  end

  # Hotwire Native: la app Android descarga aquí su path configuration
  get "configurations/android_v1", to: "configurations#android_v1",
      defaults: { format: :json }

  # Panel interno de uso (visitas + embudo de activación). Solo admins.
  get "metricas", to: "metricas#show", as: :metricas

  get "up" => "rails/health#show", as: :rails_health_check

  get "sitemap.xml", to: "sitemaps#show", as: :sitemap, defaults: { format: :xml }

  root "home#index"

  # IMPORTANTE: dejar al final — captura confianza.app/<username> como perfil.
  # Tarjeta QR imprimible de la vitrina (PNG).
  get ":id/qr", to: "profiles#qr", as: :profile_qr,
      constraints: { id: /[a-z0-9_-]+/i }, defaults: { format: :png }
  get ":id", to: "profiles#show", as: :profile,
      constraints: { id: /[a-z0-9_-]+/i }
end
