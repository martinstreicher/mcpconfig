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
      collection do
        # Fills the add form in from pasted text. It reads rather than writes,
        # but the paste is a body, not a query string, so it posts.
        post :import
      end

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

  get 'local' => 'local_servers#index', as: :local_servers

  get 'overlaps' => 'overlaps#index', as: :overlaps

  get 'projects' => 'projects#index', as: :projects
  post 'projects' => 'projects#create'
  get 'projects/show' => 'projects#show', as: :project

  # A pattern travels as a parameter for the same reason a project path does: it
  # is filesystem text, slashes and all, and does not belong in a URL segment.
  get 'ignored' => 'ignores#index', as: :ignores
  post 'ignored' => 'ignores#create'
  delete 'ignored' => 'ignores#destroy'

  get 'raw' => 'raw_configs#show', as: :raw_config
  get 'raw/edit' => 'raw_configs#edit', as: :edit_raw_config
  patch 'raw' => 'raw_configs#update'

  get 'up' => 'rails/health#show', as: :rails_health_check
end
