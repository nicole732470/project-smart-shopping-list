Rails.application.routes.draw do
  resource :session
  match "/auth/:provider/callback", to: "omniauth_callbacks#create", via: %i[ get post ]
  get "/auth/failure", to: "omniauth_callbacks#failure"
  resource :registration, only: [ :new, :create ]
  resources :passwords, param: :token
  root "products#index"
  resources :products do
    resources :price_records, only: [ :new, :create ]
    member do
      post :fetch_price
    end
  end
  resources :price_records, only: [ :index, :show, :edit, :update, :destroy ]
  get "budgetplanner", to: "budget_planner#index", as: :budget_planner

  get "about",   to: "pages#about",   as: :about
  get "privacy", to: "pages#privacy", as: :privacy
  get "terms",   to: "pages#terms",   as: :terms

  # Webhook hit by .github/workflows/refresh-prices.yml on a daily cron.
  # Auth is by shared secret (X-Admin-Token header), not by cookie session.
  post "admin/refresh_prices", to: "admin#refresh_prices"
end
