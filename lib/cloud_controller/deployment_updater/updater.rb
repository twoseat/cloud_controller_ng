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
        app = deployment.app
        web_process = app.web_process
        webish_process = deployment.webish_process

        return unless ready_to_scale?(deployment, logger)

        if web_process.instances == 0
          ProcessModel.db.transaction do
            webish_process.update(type: ProcessTypes::WEB)
            logger.info("*** web_process.type is now web-old")
            logger.info("*** Try running cf curl /v2/apps/${app.guid}")
            logger.info("*** webish_process.type is now web")
            sleep 60
            web_process.update(type: 'web-old') # was 'web'

            app_guid = app.reload.guid

            web_process.delete
            logger.info("*** web_process is deleted")
            logger.info("*** webish_process is not yet the web_process -- missing the app GUID")
            sleep 60

            # Don't do webish_process.update(guid: app_guid) because that has a validation that is going
            # to look for a process with guid = app_guid, and we're trying to set it!
            webish_process.guid = app_guid
            webish_process.save(validate: false)
            logger.info("*** webish_process now has the web_process GUID")
            sleep 60

            deployment.update(webish_process: nil, state: DeploymentModel::DEPLOYED_STATE)
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
