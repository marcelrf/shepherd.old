Shepherd::Application.routes.draw do
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)

  match '/maps/:period' => 'maps#show'
  
  resources :observations
  resources :metrics
end
