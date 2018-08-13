module Logcache
  class TrafficControllerDecorator
    def initialize(logcache_client)
      @logcache_client = logcache_client
    end

    def container_metrics(auth_token: nil, app_guid:)
      response = @logcache_client.container_metrics(app_guid: app_guid)
      response.envelopes.batch.map do |envelope|
        new_envelope = {
          applicationId: app_guid,
          instanceIndex: envelope.instance_id,
        }
        if (metrics = envelope.gauge&.metrics)
          gauge_values = {
            cpuPercentage: metrics['cpu']&.value,
            memoryBytes: metrics['memory']&.value,
            diskBytes: metrics['disk']&.value
          }
          new_envelope.merge!(gauge_values)
        end
        TrafficController::Models::Envelope.new(
          containerMetric: TrafficController::Models::ContainerMetric.new(new_envelope)
        )
      end
    end
  end
end
