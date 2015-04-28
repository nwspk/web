Rails.application.routes.draw do
  ActiveAdmin.routes(self)

  get 'dashboard',                to: 'dashboard#index'
  get 'connections',              to: 'connections#index'
  get '/auth/:provider/callback', to: 'connections#create'
  get 'membership',               to: 'home#membership'
  get 'fellowship',               to: 'home#fellowship'
  get 'contact',                  to: 'home#contact'
  get 'calendar',                 to: 'home#calendar'

  post 'webhooks',                   to: 'webhooks#index'
  post '/connections/check_friends', to: 'connections#check_friends'

  resource :subscription do
    get :checkout
    post :process_card
  end

  devise_for :users, path: 'account', controllers: { registrations: 'users/registrations' }

  root to: 'home#index'
end
