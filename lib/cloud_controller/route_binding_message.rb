module CloudController
  class RouteBindingMessage < RestAPI::Message
    optional :parameters, Hash
  end
end
