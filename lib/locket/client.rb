require 'locket/locket_services_pb'

module Locket
  class Client

    def initialize(owner, host, credentials)
      @service = CloudFoundry::Locket::Locket::Stub.new(host, credentials)
      @owner = owner
      @threads = []
    end

    def start
      threads << Thread.new do
        loop do
          begin
            service.lock(request_lock)
            @lock_acquired = true
          rescue GRPC::BadStatus
            @lock_acquired = false
          end

          sleep 1
        end
      end
    end

    def stop
      threads.each(&:kill)
    end

    def lock_acquired?
      lock_acquired
    end

    def with_lock
      yield if lock_acquired?

      sleep 1
    end

    private

    def request_lock
      CloudFoundry::Locket::LockRequest.new(
        {
          resource: {
            key: 'cc-deployment-updater',
            owner: owner,
            type_code: CloudFoundry::Locket::TypeCode::LOCK,
          },
          ttl_in_seconds: 15,
        }
      )
    end

    attr_reader :service, :owner, :lock_acquired
  end
end
