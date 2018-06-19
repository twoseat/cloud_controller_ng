require 'spec_helper'
require 'cloud_controller/deployment_updater/updater'

module VCAP::CloudController
  RSpec.describe DeploymentUpdater::Updater do
    let(:existing_process
    ) { ProcessModel.make(instances: 2) }
    let(:app_model) { existing_process
                        .app }
    let(:new_process) { ProcessModel.make(app: app_model, type: 'web-deployment-guid-1', instances: 5) }

    let(:web_process_2) { ProcessModel.make(instances: 2) }
    let(:webish_process_2) { ProcessModel.make(app: existing_process
                                                      .app, type: 'web-deployment-guid-2', instances: 5) }

    let!(:finished_deployment) { DeploymentModel.make(app: web_process_2.app, webish_process: webish_process_2, state: 'DEPLOYED') }
    let!(:deployment) { DeploymentModel.make(app: existing_process.app, webish_process: new_process, state: 'DEPLOYING') }

    let(:deployer) { DeploymentUpdater::Updater }
    let(:diego_instances_reporter) { instance_double(Diego::InstancesReporter) }
    let(:all_instances_results) {
      {
        0 => { state: 'RUNNING', uptime: 50, since: 2 },
        1 => { state: 'RUNNING', uptime: 50, since: 2 },
        2 => { state: 'RUNNING', uptime: 50, since: 2 },
      }
    }
    let(:instances_reporters) { double(:instance_reporters) }

    describe '#update' do
      before do
        allow(CloudController::DependencyLocator.instance).to receive(:instances_reporters).and_return(instances_reporters)
        allow(instances_reporters).to receive(:all_instances_for_app).and_return(all_instances_results)
      end

      context 'when all new webish processes are running' do
        context 'deployments in progress' do
          it 'scales the web process down by one' do
            expect {
              deployer.update
            }.to change {
              existing_process
                .reload.instances
            }.by(-1)
          end

          it 'scales up the new web process by one' do
            expect {
              deployer.update
            }.to change {
              new_process.reload.instances
            }.by(1)
          end
        end

        context 'the last iteration of deployments in progress' do
          let(:existing_process
          ) { ProcessModel.make(instances: 1) }
          let(:new_process) { ProcessModel.make(app: existing_process
                                                          .app, type: 'web-deployment-guid-1', instances: 5) }

          it 'scales the web process down by one' do
            expect {
              deployer.update
            }.to change {
              existing_process
                .reload.instances
            }.by(-1)
          end

          it 'does not scale up more web processes (one was created with the deployment)' do
            expect {
              deployer.update
            }.not_to change {
              new_process.reload.instances
            }
          end
        end

        context 'when the scaling is complete' do
          before do
            existing_process
              .update(instances: 0)
          end

          it 'we delete the old process, moving the webish process to web, and finish the deployment' do
            app_routes = existing_process
                           .routes
            deployer.update

            expect(ProcessModel.find(guid: existing_process
                                             .guid)).to be_nil
            expect(ProcessModel.find(guid: new_process.guid).type).to eq('web')
            expect(app_model.reload.existing_process
                     .guid).to eq(new_process.guid)
            # the new web process should have the routes of the old web process
            expect(ProcessModel.find(guid: new_process.guid).routes).to eq(app_routes)

            expect(new_process.reload.instances).to eq(5)
            expect(deployment.reload.state).to eq('DEPLOYED')
          end
        end
      end

      context 'when one of the webish instances is starting' do
        let(:all_instances_results) {
          {
            0 => { state: 'RUNNING', uptime: 50, since: 2 },
            1 => { state: 'STARTING', uptime: 50, since: 2 },
            2 => { state: 'STARTING', uptime: 50, since: 2 },
          }
        }

        it 'does not scales the process' do
          expect {
            deployer.update
          }.not_to change {
            existing_process
              .reload.instances
          }

          expect {
            deployer.update
          }.not_to change {
            new_process.reload.instances
          }
        end
      end

      context 'when one of the webish instances is failing' do
        let(:all_instances_results) {
          {
            0 => { state: 'RUNNING', uptime: 50, since: 2 },
            1 => { state: 'FAILING', uptime: 50, since: 2 },
            2 => { state: 'FAILING', uptime: 50, since: 2 },
          }
        }

        it 'does not scale the process' do
          expect {
            deployer.update
          }.not_to change {
            existing_process
              .reload.instances
          }

          expect {
            deployer.update
          }.not_to change {
            new_process.reload.instances
          }
        end
      end

      context 'when diego is unavailable' do
        before do
          allow(instances_reporters).to receive(:all_instances_for_app).and_raise(CloudController::Errors::ApiError.new_from_details('InstancesUnavailable', 'omg it broke'))
        end

        it 'does not scale the process' do
          expect {
            deployer.update
          }.not_to change {
            existing_process
              .reload.instances
          }

          expect {
            deployer.update
          }.not_to change {
            new_process.reload.instances
          }
        end
      end

      context 'when the deployment is in state DEPLOYED' do
        let(:deployed_process) { ProcessModel.make(instances: 2) }
        let!(:finished_deployment) { DeploymentModel.make(app: deployed_process.app, webish_process: deployed_process, state: 'DEPLOYED') }

        it 'does not scale the deployment' do
          expect {
            deployer.update
          }.not_to change {
            deployed_process.reload.instances
          }
        end
      end
    end
  end
end
