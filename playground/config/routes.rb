Rails.application.routes.draw do
  resources :books
  match "/backend-search" => 'search#index', via: [:post, :get], as: :backend_search
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
