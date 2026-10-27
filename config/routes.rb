Rails.application.routes.draw do
  # Health check for load balancers and uptime monitors.
  get "up" => "rails/health#show", as: :rails_health_check

  # Opening the bare domain goes to the admin dashboard.
  root to: redirect("/admin")

  # Files of the "database" Active Storage service (signed URLs that expire).
  get "files/:encoded_key/*filename", to: "stored_files#show", as: :stored_file, format: false

  # Vercel Cron jobs (protected by CRON_SECRET).
  get "internal/cron/subscription_reminders", to: "internal/cron#subscription_reminders"
  get "internal/cron/purge_unattached_blobs", to: "internal/cron#purge_unattached_blobs"

  # Admin dashboard (server-rendered, Arabic RTL) — super admins only.
  namespace :admin do
    get    "login",  to: "sessions#new",     as: :login
    post   "login",  to: "sessions#create"
    delete "logout", to: "sessions#destroy", as: :logout

    root "dashboard#show"

    patch "theme", to: "theme#update", as: :theme
    get "search", to: "search#index", as: :search

    resources :subscriptions, only: %i[index show] do
      member do
        get :screenshot
        patch :approve
        patch :reject
      end
    end
    resources :firms do
      member do
        patch :approve
        patch :suspend
      end
      resources :media, only: %i[create destroy], controller: "firm_media"
    end
    resources :categories, except: :show
    resources :articles, except: :show do
      member do
        patch :approve
        patch :reject
      end
    end
    resources :subscription_plans, except: :show
    resources :users, except: :destroy do
      resource :permissions, only: :update, controller: "staff_permissions"
    end
    resources :audit_events, only: :index, path: "audit"
    resources :reports, only: :index do
      patch :resolve, on: :collection
    end
  end

  namespace :api do
    namespace :v1 do
      post "auth/register", to: "auth#register"
      post "auth/login",    to: "auth#login"

      resource :me, only: %i[show update], controller: "me"
      get "me/articles", to: "articles#mine"

      resources :categories do
        get :icon, on: :member
        resources :firms, only: :index
      end
      resources :firms do
        resources :media, only: %i[index create update destroy], controller: "firm_media"
      end
      resources :articles

      get "payment_methods", to: "payment_methods#index"
      get "media_profiles", to: "media_profiles#index"
      resources :reports, only: :create
      resources :direct_uploads, only: :create
      resources :subscription_plans
      resources :subscriptions, only: %i[index show create] do
        get :payment_screenshot, on: :member
      end
      resources :notifications, only: :index do
        patch :read, on: :member
        patch :read_all, on: :collection
      end

      namespace :admin do
        resources :users, only: %i[index update]
        resources :articles, only: :index do
          member do
            patch :approve
            patch :reject
          end
        end
        resources :subscriptions, only: %i[index show] do
          member do
            get :payment_screenshot
            patch :approve
            patch :reject
          end
        end
      end
    end
  end
end
