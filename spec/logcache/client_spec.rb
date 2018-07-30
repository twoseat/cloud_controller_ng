require 'spec_helper'
require 'logcache/client'
require 'openssl'

module Logcache
  RSpec.describe Client do
    let(:logcache_response) { double(status: 200, contenttype:"boundary=#{response_boundary}", body: response_body)}
    let(:logcache_service) { instance_double(Logcache::V1::Egress::Stub, read:logcache_response) }

    let(:host) { 'logcache.capi.land' }
    let(:port) { '1234' }
    let(:client_ca_path) { File.join(Paths::FIXTURES, 'certs/bbs_ca.crt') }
    let(:client_cert_path) { File.join(Paths::FIXTURES, 'certs/bbs_client.crt') }
    let(:client_key_path) { File.join(Paths::FIXTURES, 'certs/bbs_client.key') }
    let(:credentials) { instance_double(GRPC::Core::ChannelCredentials) }
    let(:client) do
      Logcache::Client.new(host: host, port: port, client_ca_path: client_ca_path,
        client_cert_path: client_cert_path, client_key_path: client_key_path)
    end
    let(:expected_request_options) { { 'headers' => { 'Authorization' => 'bearer oauth-token' } } }

    before do
      client_ca = File.open(client_ca_path).read
      client_key = File.open(client_key_path).read
      client_cert = File.open(client_cert_path).read

      allow(GRPC::Core::ChannelCredentials).to receive(:new).
                    with(client_ca, client_key, client_cert).
                    and_return(credentials)

      allow(Logcache::V1::Egress::Stub).to receive(:new).
        with("#{host}:#{port}", credentials).
        and_return(logcache_service)
    end

    def build_response_body(boundary, encoded_envelopes)
      body = []
      encoded_envelopes.each do |env|
        body << "--#{boundary}"
        body << ''
        body << env
      end
      body << "--#{boundary}--"

      body.join("\r\n")
    end

    describe '#container_metrics' do
      let(:response_boundary) { SecureRandom.uuid }
      let(:response_body) do
        gaugeMap1 = {
          cpuPercentage: Loggregator::V2::GaugeValue.encode(Loggregator::V2::GaugeValue.new(unit:'percentage', value:10)),
          memoryBytes: Loggregator::V2::GaugeValue.encode(Loggregator::V2::GaugeValue.new(unit:'bytes', value:20_000)),
          diskBytes: Loggregator::V2::GaugeValue.encode(Loggregator::V2::GaugeValue.new(unit:'bytes', value:30_000_000)),
        }
        gauge1 = Loggregator::V2::Gauge.encode(Loggregator::V2::Gauge.new('metrics' => gaugeMap1))
        gaugeMap2 = {
          'cpuPercentage' => Loggregator::V2::GaugeValue.encode(Loggregator::V2::GaugeValue.new(unit:'percentage', value:11)),
          'memoryBytes' => Loggregator::V2::GaugeValue.encode(Loggregator::V2::GaugeValue.new(unit:'bytes', value:20_001)),
          'diskBytes' => Loggregator::V2::GaugeValue.encode(Loggregator::V2::GaugeValue.new(unit:'bytes', value:30_000_001)),
        }
        gauge2 = Loggregator::V2::Gauge.encode(Loggregator::V2::Gauge.new(metrics: gaugeMap2))
        build_response_body(response_boundary, [
          Loggregator::V2::Envelope.encode(Loggregator::V2::Envelope.new(source_id: 'a', gauge: gauge1), ),
          Loggregator::V2::Envelope.encode(Loggregator::V2::Envelope.new(source_id: 'b', gauge: gauge2)),
        ])
      end
      let(:app_guid) { 'example-app-guid' }

      it 'returns an array of Envelopes' do
        metrics = client.container_metrics(app_guid: 'example-app-guid')
        expect(metrics.map {|envelope| envelope['source_id']}).to match_array(['a', 'b'])
      end

    end
  end

end
