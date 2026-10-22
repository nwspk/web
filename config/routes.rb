require 'sidekiq/web'

Rails.application.routes.draw do
  ActiveAdmin.routes(self)

  get 'account', to: 'dashboard#index', as: 'dashboard'
  get 'api/events', to: 'api#events'
  get 'about', to: 'home#about', as: :about
  get 'fellowship', to: 'home#fellowship', as: :fellowship
  get 'visit', to: 'home#visit', as: :visit
  get 'study-with-us', to: 'home#study_with_us', as: :study_with_us
  get 'faculty', to: 'home#faculty', as: :faculty
  get 'residency', to: 'home#residency', as: :residency
  get 'residents', to: 'home#residents', as: :residents
  get 'scholarships', to: 'home#scholarships', as: :scholarships
  get 'donate', to: 'home#donate', as: :donate
  get 'shop', to: redirect('https://nwspk.myshopify.com/'), as: :shop
  get 'feedback', to: 'home#feedback', as: :feedback
  post 'feedback', to: 'home#submit_feedback'
  get 'rationclub', to: redirect('https://forms.gle/T3rXorsrb4gXKazv9'), as: :rationclub
  get 'library', to: 'home#library', as: :library
  get 'jobs', to: 'home#jobs', as: :jobs
  
  get '2023', to: 'home#course2023', as: :course2023
  
  get '2024', to: 'home#course2024', as: :course2024
  
  get '2025', to: 'home#course2025', as: :course2025
  # 302 rather than the 301 the other short links use: earlier years became on-site pages,
  # and a cached 301 would keep sending returning visitors to the doc after this one does too.
  get '2026', to: redirect('https://docs.google.com/document/d/12tVn3welgutGo3xd4UGkIg__MZANENu7_Kd5lyS1SDg', status: 302), as: :course2026
  get 'fieldwork25', to: redirect('https://docs.google.com/document/d/19eLJIlsOuKmC0sMlSqC-C8gGmI9XIOtS_8jQ5pHBuWc'), as: :fieldwork25
  get 'pairwork25', to: redirect('https://docs.google.com/document/d/1ZSf8g-G3rbklbpEDq_WFCykOUy921ZQwb9YZvFPbhbw'), as: :pairwork25
  get 'exclusion', to: redirect('https://docs.google.com/document/d/1sJESDvuz-M9hUeuUs-8SJrrp21afWRaYHQpYBFaJTEc'), as: :exclusion

  post 'webhooks', to: 'webhooks#index'

  # LCPT routes
  get 'lcpt', to: 'lcpt#index', as: :lcpt

  resource :subscription, only: [:edit, :update, :destroy] do
    get :checkout
    get :process_card
  end

  resource :user, only: [:edit, :update]
  resources :events, only: :index

  devise_for :users, path: 'account', controllers: { registrations: 'users/registrations', sessions: 'devise/passwordless/sessions' }

  devise_scope :user do
    get 'membership', to: 'users/registrations#new'
    post 'create-checkout-session', to: 'subscriptions#create_checkout_session', as: :create_checkout_session
    post 'customer-portal', to: 'subscriptions#customer_portal', as: :customer_portal
  end

  authenticate :user, lambda { |u| u.admin? } do
    mount Sidekiq::Web => '/sidekiq'
  end

  # Admissions (admit). The eoi-form is public, at /admissions; everything
  # under /admissions/staff is staff only, and anyone else gets the
  # ordinary not-found there.
  get 'admissions', to: 'admissions/eoi_form#show', as: :admissions_eoi_form
  post 'admissions', to: 'admissions/eoi_form#create'
  get 'admissions/thank-you', to: 'admissions/eoi_form#thanks', as: :admissions_eoi_thanks

  namespace :admissions, path: 'admissions/staff' do
    root to: 'rounds#index', as: :staff_root
    # The eoi-form's introduction and privacy notice: staff read, leads edit.
    resources :form_texts, path: 'wording', only: %i[index edit update], param: :key
    resources :rounds, only: %i[show new create edit update] do
      resources :email_templates, only: %i[index new create edit update]
    end
    # The approval queue: held emails, shared among staff.
    resources :emails, only: %i[index update] do
      member do
        post :discard
        post :confirm_sent
        post :confirm_not_sent
      end
    end
    # The kanban-board, and each applicant's page with its actions; cards
    # created by hand; the lists behind the staff home's counts (?due=…).
    get 'board', to: 'board#show', as: :board
    resources :applicants, only: %i[index show new create] do
      member do
        post :note
        post :pause_emails
        post :resume_emails
        post :flag_complicated
        post :clear_complicated
        post :hold
        post :return_from_hold
        get :move, action: :confirm_move
        post :move
        post :defer
        post :reopen
        get :withdraw, action: :confirm_withdraw
        post :withdraw
      end
    end
  end

  root to: 'home#index'

  get '*unmatched_route', to: 'application#route_not_found', constraints: { format: :html }
end
