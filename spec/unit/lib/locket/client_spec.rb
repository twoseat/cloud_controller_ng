require 'spec_helper'
require 'locket/client'

RSpec.describe Locket::Client do
  let(:locket_service) {instance_double(CloudFoundry::Locket::Locket::Stub)}
  let(:owner) {'lock-owner'}
  let(:host) {double(:host)}
  let(:credentials) {double(:credentials)}
  let(:lock_request) do
    CloudFoundry::Locket::LockRequest.new(
      {
        resource: {key: 'cc-deployment-updater', owner: owner, type_code: CloudFoundry::Locket::TypeCode::LOCK},
        ttl_in_seconds: 15
      }
    )
  end

  let(:client) {Locket::Client.new(owner, host, credentials)}

  before do
    allow(CloudFoundry::Locket::Locket::Stub).to receive(:new).
      with(host, credentials).
      and_return(locket_service)
  end

  describe '#start' do
    it 'continuously attempts to re-acquire the lock' do
      allow(locket_service).to receive(:lock)

      client.start

      expect(locket_service).to have_received(:lock).with(lock_request).at_least(3).times
    end
  end

  describe '#with_lock' do
    context 'when it can acquire a lock' do
      it 'executes the given block' do
        allow(locket_service).to receive(:lock).
          and_return(CloudFoundry::Locket::LockResponse)

        client.start

        x = double(:x, complete: true)

        client.with_lock do
          x.complete
        end

        expect(x).to have_received(:complete)
      end
    end

    context 'when it can not acquire a lock' do
      it 'does not execute the given block' do
        allow(locket_service).to receive(:lock).
          and_raise(GRPC::BadStatus.new(GRPC::AlreadyExists))

        client.start

        x = double(:x, complete: true)

        client.with_lock do
          x.complete
        end

        expect(x).not_to have_received(:complete)
      end
    end
  end

  describe '#lock_acquired?' do
    context 'when it does not acquire a lock' do
      it 'does not report that it has a lock' do
        allow(locket_service).to receive(:lock).
          and_raise(GRPC::BadStatus.new(GRPC::AlreadyExists))

        client.start

        expect(client.lock_acquired?).to be(false)
      end
    end

    context 'when it does acquire a lock' do
      it 'reports that it has a lock' do
        allow(locket_service).to receive(:lock).
          and_return(CloudFoundry::Locket::LockResponse)

        client.start

        expect(client.lock_acquired?).to be(true)
      end
    end
  end
end
