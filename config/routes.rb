Rails.application.routes.draw do
  # Health check for load balancers and uptime monitors.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      post "auth/register", to: "auth#register"
      post "auth/login",    to: "auth#login"

      resource :me, only: %i[show update], controller: "me"

      resources :categories do
        resources :firms, only: :index
      end
      resources :firms
      resources :articles

      get "payment_methods", to: "payment_methods#index"
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
