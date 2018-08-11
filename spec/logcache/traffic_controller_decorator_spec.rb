require 'spec_helper'
require 'logcache/traffic_controller_decorator'

RSpec.describe Logcache::TrafficControllerDecorator do
  subject {described_class.new(wrapped_logcache_client).container_metrics(app_guid: app_guid)}
  let(:wrapped_logcache_client) {instance_double(Logcache::Client, container_metrics: logcache_response)}
  let(:app_guid) {'the-guid'}
  let(:logcache_response) {Logcache::V1::ReadResponse.new(envelopes: envelopes)}
  let(:envelopes) {Loggregator::V2::EnvelopeBatch.new}

  it 'calls logcache_client’s container_metrics method' do
    subject

    expect(wrapped_logcache_client).to have_received(:container_metrics)
  end

  describe 'converting from Logcache to TrafficController' do
    before do
      allow(wrapped_logcache_client).to receive(:container_metrics).and_return(logcache_response)
    end

    context 'when given an empty envelope batch' do
      let(:envelopes) {Loggregator::V2::EnvelopeBatch.new}

      it 'returns an empty array' do
        expect(subject).to eq([])
      end
    end

    context 'when given a single envelope back' do
      let(:envelopes) {
        Loggregator::V2::EnvelopeBatch.new(
          batch: [Loggregator::V2::Envelope.new(source_id: app_guid)]
        )
      }

      it 'returns an array of one envelope, formatted as Traffic Controller would' do
        expect(subject.first.containerMetric.applicationId).to eq(app_guid)
      end
    end
  end
end
