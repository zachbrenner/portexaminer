require 'sidekiq/web'
Rails.application.routes.draw do
mount Sidekiq::Web => '/sidkiq'
scope "collator" do

  get 'search_around', to: 'search#search_around', as: 'search_around' 
  get 'search/hello'
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
#   mount RailsProxy.new => '/perails/'
   root 'search#index'
   get 'search/csv' => 'search#generate_csv'

   get 'search/expand' => 'search#expand'
   get 'search' => 'search#search'
   get 'search/:search_id' => 'search#show' 
   get 'expand/:search_id' => 'search#expand'

   get 'port_examiner/' => 'snakes#index' 
   get 'port_examiner/*all' => 'snakes#index' 

end

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
