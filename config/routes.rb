Rails.application.routes.draw do
  use_doorkeeper_openid_connect
  use_doorkeeper
  resources :completions
  resources :requirements
  resources :badges
  resources :users
  resources :workshops do
    member do
      get :work
      get :review
      post :import_roster
    end
  end
  get "workshops/:id/work/:requirement_id", to: "workshops#work_requirement", as: :workshop_work_requirement
  get "workshops/:id/review/:requirement_id", to: "workshops#review_requirement", as: :workshop_review_requirement
  resource :session
  post "users/:user_id/impersonate", to: "impersonations#create", as: :impersonate_user
  delete "impersonation", to: "impersonations#destroy", as: :stop_impersonation
  resources :passwords, param: :token
  resources :internet_maps, only: [ :show, :new, :create ] do
    resources :traceroutes, only: [ :create ] do
      member do
        post :retry
      end
    end
  end

  resources :network_nodes, only: [] do
    member do
      patch :position
    end
  end

  get "password_strength", to: "password_strength#index"

  get "welcome/index"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "welcome#index"
end
