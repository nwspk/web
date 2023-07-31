require 'sidekiq/web'

Rails.application.routes.draw do
  ActiveAdmin.routes(self)

  get 'account', to: 'dashboard#index', as: 'dashboard'
  get 'api/events', to: 'api#events'
  get 'about', to: 'home#about', as: :about
  get 'fellowship', to: 'home#fellowship', as: :fellowship
  get 'visit', to: 'home#visit', as: :visit
  get 'residency', to: 'home#residency', as: :residency
  get 'residents', to: 'home#residents', as: :residents
  get 'scholarships', to: 'home#scholarships', as: :scholarships
  get '2023', to: 'home#course_2023_2024', as: :course_2023_2024
  post 'webhooks', to: 'webhooks#index'

  resource :subscription, only: [:edit, :update, :destroy] do
    get :checkout
    get :process_card
  end

  resource :user, only: :update
  resources :events, only: :index

  devise_for :users, path: 'account', controllers: { registrations: 'users/registrations' }

  devise_scope :user do
    get 'membership', to: 'users/registrations#new'
    post 'create-checkout-session', to: 'subscriptions#create_checkout_session', as: :create_checkout_session
    post 'customer-portal', to: 'subscriptions#customer_portal', as: :customer_portal
  end

  authenticate :user, lambda { |u| u.admin? } do
    mount Sidekiq::Web => '/sidekiq'
  end

  root to: 'home#index'

  get '*unmatched_route', to: 'application#route_not_found', constraints: { format: :html }
end
