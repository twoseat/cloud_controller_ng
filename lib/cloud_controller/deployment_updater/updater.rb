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
            web_process.update(type: 'web-old')
            webish_process.update(type: ProcessTypes::WEB)

            app_guid = app.reload.guid

            web_process.delete

            get_rubocop_to_complain_about_a_really_long_name_line_that_isnt_used_so_we_can_find_out_about_this_copilot_thing___get_rubocop_to_complain_about_a_really_long_name_line_that_isnt_used_so_we_can_find_out_about_this_copilot_thing = 42.1
            # Trying to do webish_process.update(guid: app_guid) runs into two validations,
            # one annoying, the second harder to deal with.
            # The first wants to dcheck copilot_enabled -- do we need to do this?
            # The second wants to do a memory check and gives this error-message
            # after the guid has been saved:

            # CloudController::Errors::ApplicationMissing: Expected app record not found in database with guid <app_guid>, coming from
            # lib/cc/app_services/app_memory_calculator.rb:32:in `app_from_db'

            webish_process.guid = app_guid
            webish_process.save(validate: false)
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
