module CloudController
  module Diego
    module LifecycleProtocol
      def self.protocol_for_type(lifecycle_type)
        if lifecycle_type == CloudController::Lifecycles::BUILDPACK
          CloudController::Diego::Buildpack::LifecycleProtocol.new
        elsif lifecycle_type == CloudController::Lifecycles::DOCKER
          CloudController::Diego::Docker::LifecycleProtocol.new
        end
      end
    end
  end
end
