Rails.application.routes.draw do
  root 'dashboard#show'

  # A server is identified by its name plus the scope (and project) it lives in.
  # Scope and project travel as query parameters: project paths are absolute
  # filesystem paths and have no business in a URL segment.
  #
  # `format: false` keeps a server named "postgres.local" from being read as a
  # ".local" format request.
  scope format: false do
    resources :servers, only: %i[index new create edit update destroy],
                        constraints: { name: %r{[^/]+} },
                        param: :name do
      member do
        get :copy
        post :copy, action: :create_copy
      end
    end
  end

  resources :backups, only: %i[index show] do
    post :restore, on: :member
  end

  resource :theme, only: :update

  get 'overlaps' => 'overlaps#index', as: :overlaps

  get 'projects' => 'projects#index', as: :projects
  post 'projects' => 'projects#create'
  get 'projects/show' => 'projects#show', as: :project

  get 'raw' => 'raw_configs#show', as: :raw_config
  get 'raw/edit' => 'raw_configs#edit', as: :edit_raw_config
  patch 'raw' => 'raw_configs#update'

  get 'up' => 'rails/health#show', as: :rails_health_check
end
