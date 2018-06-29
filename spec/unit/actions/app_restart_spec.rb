require 'spec_helper'
require 'actions/app_restart'

module VCAP::CloudController
  RSpec.describe AppRestart do
    let(:user_guid) { 'some-guid' }
    let(:user_email) { '1@2.3' }
    let(:config) { nil }
    let(:user_audit_info) { UserAuditInfo.new(user_email: user_email, user_guid: user_guid) }

    describe '#restart' do
      let(:environment_variables) { { 'FOO' => 'bar' } }
      let(:desired_state) { ProcessModel::STARTED }
      let(:app) do
        AppModel.make(
          :docker,
          desired_state:         desired_state,
          environment_variables: environment_variables
        )
      end

      let(:package) { PackageModel.make(app: app, state: PackageModel::READY_STATE) }

      let!(:droplet) { DropletModel.make(app: app) }
      let!(:web_process) { ProcessModel.make(:process, state: desired_state, app: app, type: 'web') }

      let!(:worker_process) { ProcessModel.make(:process, state: desired_state, app: app, type: 'worker') }
      let(:web_process_runner) { instance_double(VCAP::CloudController::Diego::Runner) }
      let(:worker_process_runner) { instance_double(VCAP::CloudController::Diego::Runner) }

      before do
        app.update(droplet: droplet)

        allow(web_process_runner).to receive(:stop)
        allow(web_process_runner).to receive(:start)
        allow(worker_process_runner).to receive(:stop)
        allow(worker_process_runner).to receive(:start)

        allow(VCAP::CloudController::Diego::Runner).to receive(:new) do |process, _|
          process.guid == web_process.guid ? web_process_runner : worker_process_runner
        end

        VCAP::CloudController::FeatureFlag.make(name: 'diego_docker', enabled: true)
      end

      it 'does NOT invoke the ProcessObserver after the transaction commits', isolation: :truncation do
        expect(ProcessObserver).not_to receive(:updated)
        AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
      end

      it 'creates an audit event' do
        expect_any_instance_of(Repositories::AppEventRepository).to receive(:record_app_restart).with(
          app,
          user_audit_info,
        )
        AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
      end

      context 'when the app is STARTED' do
        it 'keeps the app state as STARTED' do
          AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
          expect(app.reload.desired_state).to eq('STARTED')
        end

        it 'keeps process states to STARTED' do
          AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
          expect(web_process.reload.state).to eq('STARTED')
          expect(worker_process.reload.state).to eq('STARTED')
        end

        it 'stops running processes in the runtime' do
          expect(web_process_runner).to receive(:stop)

          expect(web_process_runner).to receive(:stop).once
          expect(worker_process_runner).to receive(:stop).once

          AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
        end

        it 'starts running processes in the runtime' do
          expect(web_process_runner).to receive(:start).once
          expect(worker_process_runner).to receive(:start).once

          AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
        end

        it 'generates a STOP usage event' do
          expect {
            AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
          }.to change { AppUsageEvent.where(state: 'STOPPED').count }.by(2)
        end

        it 'generates a START usage event' do
          expect {
            AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
          }.to change { AppUsageEvent.where(state: 'STARTED').count }.by(2)
        end

        context 'restart_webish_processess is false' do
          it 'keeps the app state as STARTED' do
            AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info, restart_webish_processes: false)
            expect(app.reload.desired_state).to eq('STARTED')
          end

          it 'keeps process states to STARTED' do
            AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info, restart_webish_processes: false)
            expect(web_process.reload.state).to eq('STARTED')
            expect(worker_process.reload.state).to eq('STARTED')
          end

          it 'stops only the non-web running processes in the runtime' do #???
            expect(web_process_runner).not_to receive(:stop) ## The only difference we've tested so far, type web
            # expect(webish_process_runner).not_to receive(:stop) ## The only difference we've tested so far, type web

            expect(worker_process_runner).to receive(:stop).once

            AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info, restart_webish_processes: false)
          end

          it 'starts running processes in the runtime' do
            expect(web_process_runner).to receive(:start).once
            expect(worker_process_runner).to receive(:start).once

            AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info, restart_webish_processes: false)
          end

          it 'generates a STOP usage event' do
            expect {
              AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info, restart_webish_processes: false)
            }.to change { AppUsageEvent.where(state: 'STOPPED').count }.by(2)
          end

          it 'generates a START usage event' do
            expect {
              AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info, restart_webish_processes: false)
            }.to change { AppUsageEvent.where(state: 'STARTED').count }.by(2)
          end
        end

        context 'when submitting the stop request to the backend fails' do
          before do
            allow(web_process_runner).to receive(:stop).and_raise(Diego::Runner::CannotCommunicateWithDiegoError.new('some-stop-error'))
            allow(worker_process_runner).to receive(:stop).and_raise(Diego::Runner::CannotCommunicateWithDiegoError.new('some-stop-error'))
          end

          it 'raises an error and keeps the existing STARTED state' do
            expect {
              AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
            }.to raise_error('some-stop-error')

            expect(app.reload.desired_state).to eq('STARTED')
          end
        end

        context 'when submitting the start request to the backend fails' do
          before do
            allow(web_process_runner).to receive(:start).and_raise(Diego::Runner::CannotCommunicateWithDiegoError.new('some-start-error'))
            allow(worker_process_runner).to receive(:start).and_raise(Diego::Runner::CannotCommunicateWithDiegoError.new('some-start-error'))
          end

          it 'raises an error and keeps the existing state' do
            expect {
              AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
            }.to raise_error('some-start-error')

            expect(app.reload.desired_state).to eq('STARTED')
          end

          it 'does not generate any additional usage events' do
            original_app_usage_event_count = AppUsageEvent.count
            expect {
              AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
            }.to raise_error('some-start-error')

            expect(AppUsageEvent.count).to eq(original_app_usage_event_count)
          end
        end
      end

      context 'when the app is STOPPED' do
        let(:desired_state) { ProcessModel::STOPPED }

        it 'changes the app state to STARTED' do
          AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
          expect(app.reload.desired_state).to eq('STARTED')
        end

        it 'changes the process states to STARTED' do
          AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
          expect(web_process.reload.reload.state).to eq('STARTED')
          expect(worker_process.reload.reload.state).to eq('STARTED')
        end

        it 'does NOT attempt to stop running processes in the runtime' do
          expect(web_process_runner).to_not receive(:stop)
          expect(worker_process_runner).to_not receive(:stop)

          AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
        end

        it 'starts running processes in the runtime' do
          expect(web_process_runner).to receive(:start).once
          expect(worker_process_runner).to receive(:start).once

          AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
        end

        it 'generates a START usage event' do
          expect {
            AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
          }.to change { AppUsageEvent.where(state: 'STARTED').count }.by(2)
        end

        it 'does not generate a STOP usage event' do
          expect {
            AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
          }.to_not change { AppUsageEvent.where(state: 'STOPPED').count }
        end

        context 'when the app is invalid' do
          before do
            allow_any_instance_of(AppModel).to receive(:update).and_raise(Sequel::ValidationFailed.new('some message'))
          end

          it 'raises an AppRestart::Error' do
            expect {
              AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
            }.to raise_error(AppRestart::Error, 'some message')
          end
        end

        context 'when the process is invalid' do
          before do
            allow_any_instance_of(ProcessModel).to receive(:update).and_raise(Sequel::ValidationFailed.new('some message'))
          end

          it 'raises an AppRestart::Error' do
            expect {
              AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
            }.to raise_error(AppRestart::Error, 'some message')
          end
        end

        context 'when submitting the start request to the backend fails' do
          before do
            allow(web_process_runner).to receive(:start).and_raise(Diego::Runner::CannotCommunicateWithDiegoError.new('some-start-error'))
            allow(worker_process_runner).to receive(:start).and_raise(Diego::Runner::CannotCommunicateWithDiegoError.new('some-start-error'))
          end

          it 'raises an error and keeps the existing state' do
            expect {
              AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
            }.to raise_error('some-start-error')

            expect(app.reload.desired_state).to eq('STOPPED')
          end

          it 'does not generate any additional usage events' do
            original_app_usage_event_count = AppUsageEvent.count
            expect {
              AppRestart.restart(app: app, config: config, user_audit_info: user_audit_info)
            }.to raise_error('some-start-error')

            expect(AppUsageEvent.count).to eq(original_app_usage_event_count)
          end
        end
      end
    end
  end
end
