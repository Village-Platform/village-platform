Rails.application.routes.draw do
  # Health check for load balancers and uptime monitors.
  get "up" => "rails/health#show", as: :rails_health_check

  # Opening the bare domain goes to the admin dashboard.
  root to: redirect("/admin")

  # Files of the "database" Active Storage service (signed URLs that expire).
  get "files/:encoded_key/*filename", to: "stored_files#show", as: :stored_file, format: false

  # Vercel Cron jobs (protected by CRON_SECRET).
  get "internal/cron/subscription_reminders", to: "internal/cron#subscription_reminders"

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
    end
    resources :categories, except: :show
    resources :articles, except: :show
    resources :subscription_plans, except: :show
    resources :users, except: :destroy do
      resources :firms, only: %i[ create destroy ], controller: "user_firms"
    end
    resources :feature_flags, except: :show do
      patch :toggle, on: :member
    end
  end

  namespace :api do
    namespace :v1 do
      post "auth/register", to: "auth#register"
      post "auth/login",    to: "auth#login"

      resource :me, only: %i[show update], controller: "me"

      resources :categories do
        get :icon, on: :member
        resources :firms, only: :index
      end
      resources :firms
      resources :articles

      get "payment_methods", to: "payment_methods#index"
      get "app_config", to: "app_config#show"
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
