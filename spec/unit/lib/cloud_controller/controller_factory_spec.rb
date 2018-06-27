require 'spec_helper'

module CloudController
  RSpec.describe ControllerFactory do
    describe '#create_controller' do
      before do
        config = CloudController::Config.config
        logger = double(:logger).as_null_object
        env = {}
        params = {}
        body = ''
        sinatra = nil

        @controller_factory = ControllerFactory.new(config, logger, env, params, body, sinatra)
        @dependency_locator = DependencyLocator.instance
      end

      it 'instantiates a CrashesController' do
        controller = @controller_factory.create_controller(CloudController::CrashesController)
        expect(controller).to be_instance_of(CloudController::CrashesController)
      end

      it 'instantiates a SpaceSummariesController' do
        controller = @controller_factory.create_controller(CloudController::SpaceSummariesController)
        expect(controller).to be_instance_of(CloudController::SpaceSummariesController)
      end

      it 'instantiates a CustomBuildpacksController' do
        controller = @controller_factory.create_controller(CloudController::BuildpacksController)
        expect(controller).to be_instance_of(CloudController::BuildpacksController)
      end

      it 'instantiates an AppsController' do
        controller = @controller_factory.create_controller(CloudController::AppsController)
        expect(controller).to be_instance_of(CloudController::AppsController)
      end

      it 'instantiates a SpacesController' do
        controller = @controller_factory.create_controller(CloudController::SpacesController)
        expect(controller).to be_instance_of(CloudController::SpacesController)
      end
    end
  end
end
