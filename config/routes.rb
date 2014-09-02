Shepherd::Application.routes.draw do
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)

  match '/maps' => 'maps#show', :period => 'hour'
  match '/', :to => redirect('/maps')
  match '/metrics/autocomplete' => 'metrics#autocomplete'
  
  resources :sources
  resources :metrics
  resources :observations
end
