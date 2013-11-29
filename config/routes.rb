Shepherd::Application.routes.draw do
  root :to => 'maps#show'

  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  
  resources :observations
  resources :metrics
end
