require 'locket/locket_services_pb'

module Locket
  class Client

    def initialize(owner, host, credentials)
      @service = CloudFoundry::Locket::Locket::Stub.new(host, credentials)
      @owner = owner
    end

    def start
      lock_request = CloudFoundry::Locket::LockRequest.new(
        {
          resource: {
            key: 'cc-deployment-updater',
            owner: owner,
            type_code: CloudFoundry::Locket::TypeCode::LOCK,
          },
          ttl_in_seconds: 15,
        }
      )
      service.lock(lock_request)
      @lock_acquired = true
    rescue GRPC::BadStatus
      @lock_acquired = false
    end

    def lock_acquired?
      lock_acquired
    end

    private

    attr_reader :service, :owner, :lock_acquired
  end
end
