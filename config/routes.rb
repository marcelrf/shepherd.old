Shepherd::Application.routes.draw do
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)

  match '/maps/:period' => 'maps#show'
  match '/metrics/autocomplete' => 'metrics#autocomplete'
  
  resources :sources
  resources :metrics
  resources :observations
end
