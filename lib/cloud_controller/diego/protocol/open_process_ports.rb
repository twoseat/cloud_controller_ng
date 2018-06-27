module CloudController
  module Diego
    class Protocol
      class OpenProcessPorts
        attr_reader :process

        def initialize(process)
          @process = process
        end

        def to_a
          return process.ports unless process.ports.nil?
          return process.docker_ports if process.docker?
          return [CloudController::ProcessModel::DEFAULT_HTTP_PORT] if process.web?
          []
        end
      end
    end
  end
end
