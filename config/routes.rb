# frozen_string_literal: true

Rails.application.routes.draw do
  # Mission Control for background job monitoring (admin only)
  authenticate :user, ->(user) { user.admin? } do
    mount MissionControl::Jobs::Engine, at: "/admin/jobs"
  end

  # PgHero database performance monitoring (super admin only)
  authenticate :user, ->(user) { user.admin? } do
    mount PgHero::Engine, at: "/admin/pghero"
  end

  # Admin routes with proper RESTful routing
  namespace :admin do
    get "dashboard/index"
    root "dashboard#index"

    # Global search
    get "search", to: "search#index"

    # Activity feed
    get "activity", to: "activity#index"

    # Health/stats endpoint (JSON)
    get "health", to: "health#show"

    # Tenant settings (for tenant owners)
    resource :tenant_settings, only: [ :show, :update ], controller: "tenant_settings"

    # Observability dashboard
    resource :observability, only: [ :show ], controller: "observability" do
      get :imports
      get :editorialisations
      get :serp_api
      get :ai_usage
    end

    # Workflow pause management
    resources :workflow_pauses, only: [ :index, :create, :destroy ] do
      collection do
        post :pause
        get :backlog
      end
      member do
        post :resume
      end
    end

    # Import runs management
    resources :import_runs, only: [ :index, :show ]

    # Super admin: Tenants management (cross-tenant)
    resources :tenants, only: [ :index, :show, :edit, :update, :destroy ] do
      member do
        post :impersonate
      end
    end

    # Invitations management
    resources :invitations, only: [ :index, :create, :destroy ] do
      member do
        post :resend
      end
    end

    # Users management
    resources :users do
      member do
        post :ban
        post :unban
        post :make_admin
        post :remove_admin
        post :assign_role
        delete :remove_role
      end
    end

    # Entries (feed + directory) management
    resources :entries do
      collection do
        post :bulk_action
      end
      member do
        post :publish
        post :unpublish
        post :editorialise
        post :enrich
        post :feature
        post :unfeature
        post :extend_expiry
        post :unschedule
        post :publish_now
        post :hide
        post :unhide
        post :lock_comments
        post :unlock_comments
      end
    end

    # Notes (user-generated short posts)
    resources :notes, only: [ :index, :show, :destroy ] do
      member do
        post :hide
        post :unhide
        post :feature
        post :unfeature
      end
    end

    # Comments moderation
    resources :comments, only: [ :index, :show, :destroy ] do
      member do
        post :hide
        post :unhide
      end
    end

    resources :categories
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
      collection do
        post :retry_failed
      end
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

    # Affiliate analytics
    resources :affiliate_clicks, only: [ :index ] do
      collection do
        get :export
      end
    end

    # Sponsorship management
    resources :sponsorships do
      member do
        post :approve
        post :pause
        post :complete
        post :reject
      end
    end

    # Business claims management
    resources :business_claims, only: [ :index, :show ] do
      member do
        post :verify
        post :reject
      end
    end

    # Business subscriptions management
    resources :business_subscriptions, only: [ :index, :show ] do
      member do
        post :cancel
      end
    end

    # User submissions moderation
    resources :submissions, only: [ :index, :show ] do
      member do
        post :approve
        post :reject
      end
    end

    # Referral program management
    resources :referrals, only: [ :index, :show, :update ]
    resources :referral_reward_tiers

    # Email automation sequences
    resources :email_sequences do
      member do
        post :enable
        post :disable
      end
      resources :email_steps, except: [ :index ]
    end

    # Network boosts management
    resources :network_boosts

    # Boost earnings dashboard
    resources :boost_earnings, only: [ :index ] do
      collection do
        get :export
      end
    end

    # Boost payouts management
    resources :boost_payouts, only: [ :index, :show, :update ]

    # Community discussions moderation
    resources :discussions, only: %i[index show destroy] do
      member do
        post :lock
        post :unlock
        post :pin
        post :unpin
      end
    end

    # Live streams management
    resources :live_streams do
      member do
        post :start
        post :end_stream
      end
    end

    # Digital products management
    resources :digital_products

    # Subscriber segmentation
    resources :subscriber_tags
    resources :subscriber_segments do
      member do
        post :preview
      end
    end
    resources :digest_subscriptions, only: %i[index show] do
      member do
        patch :update_tags
        post :send_test_digest
      end
      collection do
        post :trigger_digest_send
      end
    end
  end
  # Invitation acceptance
  get "invitations/:token", to: "invitation_acceptances#show", as: :accept_invitation
  patch "invitations/:token", to: "invitation_acceptances#update"

  devise_for :users

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # XML Sitemaps
  get "sitemap", to: "sitemaps#index", as: :sitemap, defaults: { format: :xml }
  get "sitemap/main", to: "sitemaps#main", as: :sitemap_main, defaults: { format: :xml }
  get "sitemap/listings", to: "sitemaps#listings", as: :sitemap_listings, defaults: { format: :xml }
  get "sitemap/content", to: "sitemaps#content", as: :sitemap_content, defaults: { format: :xml }

  # Dynamic robots.txt
  get "robots", to: "robots#show", as: :robots, defaults: { format: :txt }

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Affiliate tracking redirect
  get "/go/:id", to: "affiliate_redirects#show", as: :affiliate_redirect

  # Boost click tracking
  get "/boosts/:id/click", to: "boosts#click", as: :boost_click

  # Search
  get "search", to: "search#index", as: :search

  # Digest subscriptions
  resource :digest_subscription, only: [ :show, :create, :update, :destroy ]
  get "digest_subscription/confirm/:token", to: "digest_subscriptions#confirm", as: :confirm_digest
  get "digest_subscription/resend_confirmation", to: "digest_subscriptions#resend_confirmation", as: :resend_digest_confirmation
  get "unsubscribe/:token", to: "digest_subscriptions#unsubscribe", as: :unsubscribe_digest

  # User dashboard
  resource :dashboard, only: [ :show ], controller: "dashboard"

  # Referral program
  resource :referrals, only: [ :show ]

  # Bookmarks (My Saves)
  resources :bookmarks, only: [ :index, :create, :destroy ]

  # User profiles
  resources :profiles, only: [ :show, :edit, :update ]

  # User submissions
  resources :submissions, only: [ :index, :show, :new, :create ]

  # Public feed routes
  resources :feed, only: [ :index ], controller: "feed"
  get "feed/rss", to: "feed#rss", as: :feed_rss, defaults: { format: :rss }

  # RSS/Atom syndication feeds
  scope :feeds, controller: "feeds" do
    get "content", action: :content, as: :feeds_content, defaults: { format: :rss }
    get "listings", action: :listings, as: :feeds_listings, defaults: { format: :rss }
    get "categories/:id", action: :category, as: :feeds_category, defaults: { format: :rss }
  end

  # Entry engagement routes (feed + directory)
  resources :entries, only: [] do
    post :vote, to: "votes#toggle", on: :member
    resources :comments, only: %i[index show create update destroy]
    resources :views, only: [ :create ], controller: "content_views"
  end

  # Notes (short-form social content)
  resources :notes do
    post :vote, to: "note_votes#toggle", on: :member
    post :repost, on: :member
    resources :comments, controller: "note_comments", only: %i[index create update destroy]
  end

  # User-facing flag creation (for content items and comments)
  resources :flags, only: [ :create ]

  # Community discussions
  resources :discussions, only: %i[index show new create update destroy] do
    resources :posts, controller: "discussion_posts", only: %i[create update destroy]
  end

  # Digital products marketplace
  resources :products, only: %i[index show], controller: "digital_products" do
    resource :checkout, only: %i[create], controller: "product_checkouts" do
      get :success
      get :cancel
    end
  end

  # Token-based downloads (no login required)
  get "downloads/:token", to: "downloads#show", as: :download

  # User purchase history
  namespace :my do
    resources :purchases, only: %i[index show] do
      member do
        post :regenerate_token
      end
    end
  end

  # Live streams
  resources :live_streams, only: %i[index show] do
    member do
      post :join
      post :leave
    end
  end

  # Public routes for browsing content (directory entries)
  resources :categories, only: [ :index, :show ] do
    resources :listings, only: [ :index, :show ], controller: "directory"
  end

  # Direct directory routes (canonical URLs, bookmarks; path /listings for SEO)
  resources :listings, only: [ :index, :show ], controller: "directory" do
    resource :checkout, only: [ :new, :create ], controller: "checkouts" do
      get :success
      get :cancel
    end
  end

  # Stripe webhooks
  post "webhooks/stripe", to: "stripe_webhooks#create"

  # Mux webhooks (live video streaming)
  post "webhooks/mux", to: "mux_webhooks#create"

  # Public static pages (tenant-aware)
  get "about", to: "tenants#about"

  # Landing pages for marketing campaigns
  get "p/:slug", to: "landing_pages#show", as: :landing_page

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
