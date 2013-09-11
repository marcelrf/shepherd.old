Shepherd::Application.routes.draw do

  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  
  resources :observations
  resources :metrics

  match 'tasks/analyze-metric' => 'tasks#analyze_metric', :as => :analyze_metric_task

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  # root :to => 'welcome#index'
end
