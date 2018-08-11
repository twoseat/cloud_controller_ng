module Logcache
  class TrafficControllerDecorator
    def initialize(logcache_client)
      @logcache_client = logcache_client
    end

    def container_metrics(auth_token: nil, app_guid:)
      response = @logcache_client.container_metrics(app_guid: app_guid)
      response.envelopes.batch
    end
  end
end
