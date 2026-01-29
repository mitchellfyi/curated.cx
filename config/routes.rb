# frozen_string_literal: true

Rails.application.routes.draw do
  # Admin routes with proper RESTful routing
  namespace :admin do
    get "dashboard/index"
    root "dashboard#index"
    resources :categories
    resources :listings do
      member do
        post :feature
        post :unfeature
        post :extend_expiry
      end
    end
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

    # Site bans management
    resources :site_bans, only: %i[index show new create destroy]

    # Content flagging/moderation queue
    resources :flags, only: %i[index show] do
      member do
        post :resolve
        post :dismiss
      end
    end

    # Content moderation
    resources :content_items, only: [], controller: "moderation" do
      member do
        post :hide
        post :unhide
        post :lock_comments
        post :unlock_comments
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

  # Affiliate tracking redirect
  get "/go/:id", to: "affiliate_redirects#show", as: :affiliate_redirect

  # Search
  get "search", to: "search#index", as: :search

  # Digest subscriptions
  resource :digest_subscription, only: [ :show, :create, :update, :destroy ]
  get "unsubscribe/:token", to: "digest_subscriptions#unsubscribe", as: :unsubscribe_digest

  # Bookmarks (My Saves)
  resources :bookmarks, only: [ :index, :create, :destroy ]

  # User profiles
  resources :profiles, only: [ :show, :edit, :update ]

  # Public feed routes
  resources :feed, only: [ :index ], controller: "feed"
  get "feed/rss", to: "feed#rss", as: :feed_rss, defaults: { format: :rss }

  # Content item engagement routes
  resources :content_items, only: [] do
    # Vote toggle
    post :vote, to: "votes#toggle", on: :member
    # Comments
    resources :comments, only: %i[index show create update destroy]
  end

  # User-facing flag creation (for content items and comments)
  resources :flags, only: [ :create ]

  # Public routes for browsing content
  resources :categories, only: [ :index, :show ] do
    resources :listings, only: [ :index, :show ]
  end

  # Direct listing routes (for canonical URLs, bookmarks, etc.)
  resources :listings, only: [ :index, :show ]

  # Public static pages (tenant-aware)
  get "about", to: "tenants#about"

  # Marketing pages (root domain only)
  get "pricing", to: "marketing#pricing"
  get "features", to: "marketing#features"

  # Tenant routes
  resources :tenants, only: [ :index, :show ]

  # Defines the root path route ("/")
  root "tenants#show"

  # Domain not connected error page (handled by middleware)
  get "domain_not_connected", to: "domain_not_connected#show"
end
