Rails.application.routes.draw do
  resources :items, only: :show do
    member do
      patch :hide
      patch :unhide
    end
  end
  resources :posts, only: %i[ index create destroy ] do
    scope module: :posts do
      resource :pins, only: :create
      resource :title, only: %i[ show edit update ]
      resource :item_order, only: :update
      resources :hidden_items, only: :index
    end
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  root "posts#index"
end
