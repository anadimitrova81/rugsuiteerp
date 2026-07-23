Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # ===== Platform operator console (admin.rugsuiteerp.com) =====
  # Cross-tenant super-admin. Must come before the marketing + tenant routes so
  # the admin host is claimed first. Platform controllers don't run the tenant
  # filter.
  constraints ->(req) { HostType.platform?(req) } do
    root "platform/subscriptions#index", as: :platform_root
    get    "login",  to: "platform/sessions#new",     as: :platform_login
    post   "login",  to: "platform/sessions#create"
    delete "logout", to: "platform/sessions#destroy", as: :platform_logout

    resources :subscriptions, only: %i[show], controller: "platform/subscriptions",
                              as: :platform_subscription do
      post :impersonate, to: "platform/impersonations#create", on: :member
    end
  end

  # ===== Marketing site (apex / reserved subdomains) =====
  # Lives at the bare hostname (e.g. rugsuite.app, www.rugsuite.app, or
  # rugsuiteerp.localhost in dev). Marketing controllers don't run the tenant
  # filter, so HostType.marketing? must match here.
  constraints ->(req) { HostType.marketing?(req) } do
    root "marketing/pages#home", as: :marketing_root
    get  "signup", to: "marketing/signups#new",    as: :marketing_signup
    post "signup", to: "marketing/signups#create"
  end

  # ===== Tenant app (real factory subdomains) =====
  # Defines the root path route ("/") for tenant-facing customers.
  root "pages#home"
  get "faq", to: "pages#faq", as: :faq
  get "contacts", to: "pages#contacts", as: :contacts
  get "terms", to: "pages#terms", as: :terms
  get "privacy", to: "pages#privacy", as: :privacy

  resources :requests, only: %i[new create show]

  get "status", to: "status#show", as: :status
  get "r/:token", to: "status#short", as: :short_status, constraints: { token: /[a-f0-9]{8}/ }

  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout

  # Platform-admin impersonation hand-off: the operator console mints a signed,
  # short-lived token and redirects here (on the tenant subdomain) to establish
  # the impersonated session. `destroy` ends the impersonation.
  get    "enter", to: "platform_handoffs#show",    as: :platform_enter
  delete "enter", to: "platform_handoffs#destroy", as: :platform_exit

  namespace :admin do
    resources :requests, only: %i[index show new create edit update]
    resources :users, only: %i[index new create update destroy] do
      post :impersonate, on: :member
    end
    delete "impersonate", to: "users#stop_impersonating", as: :stop_impersonating
    resources :reports, only: %i[index]
    resources :address_lookups, only: %i[create]

    resource :route, only: %i[show], controller: "routes" do
      post :optimize
      post :calculate
      patch :reorder
      post :swap
    end

    resource :notifications, only: [] do
      post :price_quotes
    end

    get "sms_log", to: "sms_log#index", as: :sms_log

    resource :settings, only: %i[show update]
    resource :subscription, only: %i[show update]
    resources :process_steps, only: %i[new create edit update destroy] do
      patch :move, on: :member
    end
  end
end
