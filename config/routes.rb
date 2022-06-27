require 'sidekiq/web'

Rails.application.routes.draw do
  ActiveAdmin.routes(self)

  get 'account',                  to: 'dashboard#index', as: 'dashboard'
  get 'api/events',               to: 'api#events'
  get 'about',                    to: 'home#about', as: :about
  get 'fellowship',               to: 'home#fellowship', as: :fellowship
  get 'visit',                    to: 'home#visit', as: :visit
  get 'residency',                to: 'home#residency', as: :residency
  get 'scholarships',             to: 'home#scholarships', as: :scholarships
  post 'webhooks',                to: 'webhooks#index'

  resource :subscription, only: [:edit, :update, :destroy] do
    get :checkout
    post :process_card
  end

  resource :user, only: :update
  resources :events, only: :index

  devise_for :users, path: 'account', controllers: { registrations: 'users/registrations' }

  devise_scope :user do
    get 'membership', to: 'users/registrations#new'
  end

  authenticate :user, lambda { |u| u.admin? } do
    mount Sidekiq::Web => '/sidekiq'
  end

  root to: 'home#index'

  get '*unmatched_route', to: 'application#route_not_found', constraints: { format: :html }
end
