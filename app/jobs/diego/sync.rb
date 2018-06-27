require 'cloud_controller/diego/processes_sync'
require 'cloud_controller/diego/tasks_sync'
require 'statsd'
require 'cloud_controller/copilot/sync'

module CloudController
  module Jobs
    module Diego
      class Sync < CloudController::Jobs::CCJob
        def initialize(statsd=Statsd.new)
          @statsd = statsd
        end

        def perform
          config = CloudController::DependencyLocator.instance.config
          @statsd.time('cc.diego_sync.duration') do
            CloudController::Diego::ProcessesSync.new(config: config).sync
            CloudController::Diego::TasksSync.new(config: config).sync
          end
        end

        private

        def logger
          @logger ||= Steno.logger('cc.diego.sync.perform')
        end
      end
    end
  end
end
