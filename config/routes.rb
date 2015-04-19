Rails.application.routes.draw do
  get 'dashboard', to: 'dashboard#index'

  post 'webhooks', to: 'webhooks#index'

  get '/auth/:provider/callback', to: 'connections#create'

  resource :subscription do
    get :checkout
    post :process_card
  end

  devise_for :users, path: 'account', controllers: { registrations: 'users/registrations' }

  root to: 'home#index'
end
