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
      resources :subscriptions, only: %i[index show create]

      namespace :admin do
        resources :users, only: %i[index update]
        resources :subscriptions, only: %i[index show] do
          member do
            patch :approve
            patch :reject
          end
        end
      end
    end
  end
end
