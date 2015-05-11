CiteCollections::Application.routes.draw do
  
  get "cite/index"
  resources :versions, :constraints => {:id => /urn:cite:\w+:\w+\.*\w*\.*\w*-*\w*/}, only: [:index, :show, :edit, :update] do
    collection do
      get 'search'
    end
  end

  resources :works, :constraints => {:id => /urn:cite:\w+:\w+\.*\w*\.*\w*-*\w*/}, only: [:index, :show, :edit, :update] do
    collection do
        get 'search'
      end
    end

  resources :textgroups, :constraints => {:id => /urn:cite:\w+:\w+\.*\w*\.*\w*-*\w*/}, only: [:index, :show, :edit, :update] do
    collection do
      get 'search'
    end
  end

  resources :authors, :constraints => {:id => /urn:cite:\w+:\w+\.*\w*\.*\w*-*\w*/}, only: [:index, :show, :edit, :update] do
    collection do
      get 'search'
    end
  end

  get 'forms' => 'forms#index'
  post 'forms/search' => 'forms#search'
  post 'forms/reserve' => 'forms#reserve'
  post 'forms/create' => 'forms#create'
  post 'forms/mods' => 'forms#mods'

  namespace :api do
    resources :authors, :works, :textgroups, :versions, :constraints => {:id => /urn:cite:\w+:\w+\.*\w*\.*\w*-*\w*/}, only: [:index, :show] do
      collection do
        get 'count'
        get 'first'
        get 'last'
        get 'search'
      end
      member do
        get 'previous'
        get 'next'
        get 'prevnext'
      end
    end
    
  end


    

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
   root 'cite#index'

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
