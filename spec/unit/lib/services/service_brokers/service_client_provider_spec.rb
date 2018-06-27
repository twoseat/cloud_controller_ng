require 'spec_helper'

RSpec.describe Services::ServiceClientProvider do
  describe '#provide' do
    context 'service instances' do
      context 'when the instance is a UserProvidedServiceInstance' do
        let(:service_instance) { CloudController::UserProvidedServiceInstance.make }

        before do
          allow(Services::ServiceBrokers::UserProvided::Client).to receive(:new).and_call_original
        end

        it 'returns a client for a user provided service' do
          Services::ServiceClientProvider.provide(instance: service_instance)
          expect(Services::ServiceBrokers::UserProvided::Client).to have_received(:new)
        end
      end

      context 'when the instance is a ManagedServiceInstance' do
        let(:service_instance) { CloudController::ManagedServiceInstance.make }
        let(:expected_attrs) do
          {
            url: service_instance.service_broker.broker_url,
            auth_username: service_instance.service_broker.auth_username,
            auth_password: service_instance.service_broker.auth_password
          }
        end

        before do
          allow(Services::ServiceBrokers::V2::Client).to receive(:new).and_call_original
        end

        it 'returns a service broker client' do
          Services::ServiceClientProvider.provide(instance: service_instance)
          expect(Services::ServiceBrokers::V2::Client).to have_received(:new).with(expected_attrs)
        end
      end
    end

    context 'service brokers' do
      let(:broker) { CloudController::ServiceBroker.make }
      let(:expected_attrs) do
        {
          url: broker.broker_url,
          auth_username: broker.auth_username,
          auth_password: broker.auth_password
        }
      end

      before do
        allow(Services::ServiceBrokers::V2::Client).to receive(:new).and_call_original
      end

      it 'returns a client for a broker' do
        Services::ServiceClientProvider.provide(broker: broker)
        expect(Services::ServiceBrokers::V2::Client).to have_received(:new).with(expected_attrs)
      end
    end

    context 'when no binding or service instance' do
      it 'returns nil' do
        client = Services::ServiceClientProvider.provide
        expect(client).to be_nil
      end
    end
  end
end
