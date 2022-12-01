Rails.application.routes.draw do
  root to: 'books#index'

  resources :songs, only: :index
  resources :books, except: :show
end
