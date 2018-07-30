
require 'logcache/logcache_egress_services_pb'
require 'logcache/v2/envelope_pb'
require 'utils/multipart_parser_wrapper'

module Logcache
  class Error < StandardError
  end
  class ResponseError < StandardError
  end
  class RequestError < StandardError
  end
  class DecodeError < StandardError
  end
  class Client
    BOUNDARY_REGEXP = /boundary=(.+)/

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
      response = with_request_error_handling do
        service.read(build_read_request(app_guid))
      end

      validate_status!(response: response, statuses: [200])

      envelopes = []
      boundary  = extract_boundary!(response.contenttype)
      parser    = VCAP::MultipartParserWrapper.new(body: response.body, boundary: boundary)
      until (next_part = parser.next_part).nil?
        envelopes << convert_to_container_metric(protobuf_decode!(next_part, Loggregator::V2::Envelope))
      end
      envelopes.compact
    end

    def with_request_error_handling(&blk)
      tries ||= 3
      yield
    rescue => e
      retry unless (tries -= 1).zero?
      raise RequestError.new(e.message)
    end

    private

    def build_read_request(source_id)
      Logcache::V1::ReadRequest.new(
        {
          source_id: source_id
        }
      )
    end

    def extract_boundary!(content_type)
      match_data = BOUNDARY_REGEXP.match(content_type)
      raise ResponseError.new('failed to find multipart boundary in Content-Type header') if match_data.nil?

      match_data.captures.first
    end

    def validate_status!(response:, statuses:)
      raise ResponseError.new("failed with status: #{response.status}, body: #{response.body}") unless statuses.include?(response.status)
    end

    def protobuf_decode!(message, protobuf_decoder)
      protobuf_decoder.decode(message)
    rescue => e
      raise DecodeError.new(e.message)
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
