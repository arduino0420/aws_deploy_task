Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root 'blogs#index'
  resources :blogs
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
