Rails.application.routes.draw do
  resource :session
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
end
