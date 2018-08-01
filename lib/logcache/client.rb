require 'logcache/logcache_egress_services_pb'
require 'logcache/v2/envelope_pb'
require 'utils/multipart_parser_wrapper'

module Logcache
  class Client
    attr_reader :service

    def initialize(host:, port:, client_ca_path:, client_cert_path:, client_key_path:)
      client_ca = File.open(client_ca_path).read
      client_key = File.open(client_key_path).read
      client_cert = File.open(client_cert_path).read

      @service = Logcache::V1::Egress::Stub.new(
        "#{host}:#{port}",
        GRPC::Core::ChannelCredentials.new(client_ca, client_key, client_cert)
      )
    end

    def container_metrics(auth_token: nil, app_guid:)
      @logger ||= Steno.logger('logcache.client')
      response = service.read(build_read_request(app_guid))
      @logger.info("QQQ: Logcache.container_metrics => #{response}")
      envelopes = response.envelopes # could response be missing/nil? catch/handle nil response?
      return [] if envelopes.nil? # envelopes is optional, could be missing
      # get stats from logcache via grpc

      body = {}

      body[:stats] = envelopes.map {|envelope| convert_to_container_metric(envelope) }
      body # convert to be consumable by stats presenter
    rescue StandardError => e
      @logger.error("QQQ: Error! : #{e}")
      raise
    end

    private

    def build_read_request(source_id)
      Logcache::V1::ReadRequest.new(
        {
          source_id: source_id
        }
      )
    end

    def convert_to_container_metric(envelope)
      gauge = envelope['gauge']
      return nil unless gauge
      container_metric = ContainerMetric.new(gauge['instanceIndex']['value'], gauge['cpuPercentage']['value'], gauge['memoryBytes']['value'], \
    gauge['diskBytes']['value'])
      ContainerMetricHolder.new(container_metric)
    end
  end
end
