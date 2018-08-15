require 'spec_helper'
require 'logcache/traffic_controller_decorator'

RSpec.describe Logcache::TrafficControllerDecorator do
  subject { described_class.new(wrapped_logcache_client).container_metrics(app_guid: app_guid) }
  let(:wrapped_logcache_client) { instance_double(Logcache::Client, container_metrics: logcache_response) }

  let(:num_instances) { 1 }
  let(:web_process) { instance_double(VCAP::CloudController::ProcessModel, instances: num_instances) }
  let(:app) { instance_double(VCAP::CloudController::AppModel, web_process: web_process) }
  let(:app_guid) { 'the-guid' }
  let(:logcache_response) { Logcache::V1::ReadResponse.new(envelopes: envelopes) }
  let(:envelopes) { Loggregator::V2::EnvelopeBatch.new }

  describe 'converting from Logcache to TrafficController' do
    before do
      allow(wrapped_logcache_client).to receive(:container_metrics).and_return(logcache_response)
      allow(VCAP::CloudController::AppModel).to receive(:find).and_return(app)
    end

    it 'calls logcache_client’s container_metrics method' do
      subject

      expect(wrapped_logcache_client).to have_received(:container_metrics)
    end

    context 'when given an empty envelope batch' do
      let(:envelopes) { Loggregator::V2::EnvelopeBatch.new }

      it 'returns an empty array' do
        expect(subject).to eq([])
      end
    end

    context 'when given a single envelope back' do
      let(:envelopes) {
        Loggregator::V2::EnvelopeBatch.new(
          batch: [Loggregator::V2::Envelope.new(
            source_id: app_guid,
            gauge: Loggregator::V2::Gauge.new(metrics: {
              'cpu' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 10),
              'memory' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 11),
              'disk' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 12),
            }),
            instance_id: '1'
          )]
        )
      }

      it 'returns an array of one envelope, formatted as Traffic Controller would' do
        expect(subject.first.containerMetric.applicationId).to eq(app_guid)
        expect(subject.first.containerMetric.instanceIndex).to eq(1)
        expect(subject.first.containerMetric.cpuPercentage).to eq(10)
        expect(subject.first.containerMetric.memoryBytes).to eq(11)
        expect(subject.first.containerMetric.diskBytes).to eq(12)
      end
    end

    context 'when given multiple envelopes back' do
      let(:envelopes) {
        Loggregator::V2::EnvelopeBatch.new(
          batch: [
            Loggregator::V2::Envelope.new(
              source_id: app_guid,
              gauge: Loggregator::V2::Gauge.new(metrics: {
                'cpu' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 10),
                'memory' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 11),
                'disk' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 12),
              }),
              instance_id: '1'
            ),
            Loggregator::V2::Envelope.new(
              source_id: app_guid,
              gauge: Loggregator::V2::Gauge.new(metrics: {
                'cpu' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 20),
                'memory' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 21),
                'disk' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 22),
              }),
              instance_id: '2'
            ),
            Loggregator::V2::Envelope.new(
              source_id: app_guid,
              gauge: Loggregator::V2::Gauge.new(metrics: {
                'cpu' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 30),
                'memory' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 31),
                'disk' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 32),
              }),
              instance_id: '3'
            )
          ]
        )
      }
      let(:num_instances) { 3 }

      it 'returns an array of one envelope, formatted as Traffic Controller would' do
        expect(subject.first.containerMetric.applicationId).to eq(app_guid)
        expect(subject.first.containerMetric.instanceIndex).to eq(1)
        expect(subject.first.containerMetric.cpuPercentage).to eq(10)
        expect(subject.first.containerMetric.memoryBytes).to eq(11)
        expect(subject.first.containerMetric.diskBytes).to eq(12)

        expect(subject.second.containerMetric.applicationId).to eq(app_guid)
        expect(subject.second.containerMetric.instanceIndex).to eq(2)
        expect(subject.second.containerMetric.cpuPercentage).to eq(20)
        expect(subject.second.containerMetric.memoryBytes).to eq(21)
        expect(subject.second.containerMetric.diskBytes).to eq(22)

        cm = subject[2].containerMetric
        expect(cm.applicationId).to eq(app_guid)
        expect(cm.instanceIndex).to eq(3)
        expect(cm.cpuPercentage).to eq(30)
        expect(cm.memoryBytes).to eq(31)
        expect(cm.diskBytes).to eq(32)
      end
    end

    context 'when given multiple metrics for the same instance' do
      let(:envelopes) {
        Loggregator::V2::EnvelopeBatch.new(
          batch: [
            Loggregator::V2::Envelope.new(
              source_id: app_guid,
              gauge: Loggregator::V2::Gauge.new(metrics: {
                'cpu' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 10),
                'memory' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 11),
                'disk' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 12),
              }),
              instance_id: '1'
            ),
            Loggregator::V2::Envelope.new(
              source_id: app_guid,
              gauge: Loggregator::V2::Gauge.new(metrics: {
                'cpu' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 20),
                'memory' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 21),
                'disk' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 22),
              }),
              instance_id: '2'
            ),
            Loggregator::V2::Envelope.new(
              source_id: app_guid,
              gauge: Loggregator::V2::Gauge.new(metrics: {
                'cpu' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 30),
                'memory' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 31),
                'disk' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 32),
              }),
              instance_id: '1'
            )
          ]
        )
      }
      let(:num_instances) { 2 }

      it 'returns only the newest metric' do
        expect(subject.count).to eq(2)
        expect(subject.first.containerMetric.instanceIndex).to eq(1)
        expect(subject.first.containerMetric.cpuPercentage).to eq(10)
        expect(subject.second.containerMetric.instanceIndex).to eq(2)
      end
    end
  end
end
