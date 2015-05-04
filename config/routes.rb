Rails.application.routes.draw do
  ActiveAdmin.routes(self)

  get 'dashboard',                to: 'dashboard#index'
  get 'connections',              to: 'connections#index'
  get '/auth/:provider/callback', to: 'connections#create'
  get 'fellowship',               to: 'home#fellowship'
  get 'contact',                  to: 'home#contact'
  get 'calendar',                 to: 'home#calendar'
  get 'api/uid',                  to: 'api#uid'

  post 'webhooks',                   to: 'webhooks#index'
  post '/connections/check_friends', to: 'connections#check_friends'

  resource :subscription do
    get :checkout
    post :process_card
  end

  devise_for :users, path: 'account', controllers: { registrations: 'users/registrations' }

  devise_scope :user do
    get 'membership', to: 'users/registrations#new'
  end

  root to: 'home#index'
end
