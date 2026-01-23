# frozen_string_literal: true

Rails.application.routes.draw do
  # Admin routes with proper RESTful routing
  namespace :admin do
    get "dashboard/index"
    root "dashboard#index"
    resources :categories
    resources :listings
    resources :taxonomies
    resources :tagging_rules do
      member do
        get :test
      end
    end
    resources :sites do
      resources :domains, except: [ :index ] do
        member do
          post :check_dns
        end
      end
    end
    resources :sources do
      member do
        post :run_now
      end
    end
    resources :editorialisations, only: [ :index, :show ] do
      member do
        post :retry
      end
    end
  end
  devise_for :users

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Public routes for browsing content
  resources :categories, only: [ :index, :show ] do
    resources :listings, only: [ :index, :show ]
  end

  # Direct listing routes (for canonical URLs, bookmarks, etc.)
  resources :listings, only: [ :index, :show ]

  # Public static pages (tenant-aware)
  get "about", to: "tenants#about"

  # Tenant routes
  resources :tenants, only: [ :index, :show ]

  # Defines the root path route ("/")
  root "tenants#show"

  # Domain not connected error page (handled by middleware)
  get "domain_not_connected", to: "domain_not_connected#show"
end
