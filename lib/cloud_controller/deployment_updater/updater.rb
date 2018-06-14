module VCAP::CloudController
  module DeploymentUpdater
    class Updater
      def self.update
        logger = Steno.logger('cc.deployment_updater.update')
        logger.info('run-deployment-update')

        deployments = DeploymentModel.where(state: DeploymentModel::DEPLOYING_STATE)

        deployments.each do |deployment|
          scale_deployment(deployment, logger)
        end
      end

      private_class_method

      def self.scale_deployment(deployment, logger)
        return unless ready_to_scale?(deployment, logger)

        app = deployment.app
        web_process = app.web_process
        webish_process = deployment.webish_process
        final_web_process = deployment.final_web_process

        if final_web_process
          if webish_process.instance == 0
            webish_process.delete
            deployment.update(final_web_process:nil, state: DeploymentModel::DEPLOYED_STATE)
          else
            ProcessModel.db.transaction do
              webish_process.update(instances: webish_process.instances - 1)
              deployment.final_web_process.update(instances: final_web_process.instances + 1)
            end
          end
        elsif web_process.instances == 0
          ProcessModel.db.transaction do
            web_process.delete
            process_values = webish_process.values.delete(:id)
            deployment.final_web_process = ProcessModel.create(process_values.merge({guid: app.guid, type: ProcessTypes::WEB})
          end
        elsif web_process.instances == 1
          web_process.update(instances: web_process.instances - 1)
        else
          ProcessModel.db.transaction do
            web_process.update(instances: web_process.instances - 1)
            webish_process.update(instances: webish_process.instances + 1)
          end
        end

        logger.info("ran-deployment-update-for-#{deployment.guid}")
      end

      def self.ready_to_scale?(deployment, logger)
        instances = instance_reporters.all_instances_for_app(deployment.webish_process)
        instances.all? { |_, val| val[:state] == VCAP::CloudController::Diego::LRP_RUNNING }
      rescue CloudController::Errors::ApiError # the instances_reporter re-raises InstancesUnavailable as ApiError
        logger.info("skipping-deployment-update-for-#{deployment.guid}")
        return false
      end

      def self.instance_reporters
        CloudController::DependencyLocator.instance.instances_reporters
      end
    end
  end
end
