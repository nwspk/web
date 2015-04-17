Rails.application.routes.draw do
  get 'dashboard', to: 'dashboard#index'

  resource :subscription do
    get :checkout
    post :process_card
  end

  devise_for :users, path: 'account', controllers: { registrations: 'users/registrations' }

  root to: 'home#index'
end
