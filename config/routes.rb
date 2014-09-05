Shepherd::Application.routes.draw do
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)

  match '/status' => 'maps#show', :period => 'hour'
  match '/', :to => redirect('/status')
  match '/metrics/autocomplete' => 'metrics#autocomplete'
  match '/alerts/autocomplete' => 'alerts#autocomplete'
  
  resources :sources
  resources :metrics
  resources :alerts
end
