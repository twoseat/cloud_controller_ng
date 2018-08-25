require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe BuildpackInstaller, job_context: :worker do
      let(:zipfile) {File.expand_path('../../../fixtures/good.zip', File.dirname(__FILE__))}
      let(:zipfile2) {File.expand_path('../../../fixtures/good_relative_paths.zip', File.dirname(__FILE__))}

      let(:new_buildpack_options) {{enabled: true, locked: true, position: 1}}
      let(:job_options) {{name: 'mybuildpack', stack: 'mystack', file: zipfile, opts: new_buildpack_options,
        action: VCAP::CloudController::Jobs::Runtime::BuildpackInstallerOptionsFactory::CREATE_BUILDPACK}}
      let(:job) {BuildpackInstaller.new(job_options)}

      it 'is a valid job' do
        expect(job).to be_a_valid_job
      end

      describe '#perform' do
        context 'when creating a buildpack' do
          context 'when the requested stack does not exist' do
            let(:job_options) {{name: 'mybuildpack', stack: 'mystack', file: zipfile, opts: new_buildpack_options,
              action: VCAP::CloudController::Jobs::Runtime::BuildpackInstallerOptionsFactory::CREATE_BUILDPACK}}

            it 'creates a new buildpack with stack' do
              expect {
                job.perform
              }.to change {Buildpack.count}.from(0).to(1)

              buildpack = Buildpack.first
              expect(buildpack).to_not be_nil
              expect(buildpack.name).to eq('mybuildpack')
              expect(buildpack.stack).to eq('mystack')
              expect(buildpack.key).to start_with(buildpack.guid)
              expect(buildpack.filename).to end_with(File.basename(zipfile))
              expect(buildpack).to be_locked
            end
          end

          context 'when the requested stack does exist' do
            let!(:existing_stack) {Stack.make(name: 'mystack')}
            let(:job_options) {{name: 'mybuildpack', stack: 'mystack', file: zipfile, opts: new_buildpack_options,
              action: VCAP::CloudController::Jobs::Runtime::BuildpackInstallerOptionsFactory::CREATE_BUILDPACK}}

            it 'does not create a new stack' do
              expect {
                job.perform
              }.not_to change {Stack.count}
            end

            it 'creates a new buildpack with stack' do
              expect {
                job.perform
              }.to change {Buildpack.count}.from(0).to(1)

              buildpack = Buildpack.first
              expect(buildpack).to_not be_nil
              expect(buildpack.name).to eq('mybuildpack')
              expect(buildpack.stack).to eq('mystack')
              expect(buildpack.key).to start_with(buildpack.guid)
              expect(buildpack.filename).to end_with(File.basename(zipfile))
              expect(buildpack).to be_locked
            end
          end
        end

        context 'when a buildpack should be upgraded' do
          let(:new_buildpack_options) {{locked: true}}
          let(:existing_stack) {Stack.make(name: 'stack-1')}
          let(:existing_buildpack) {Buildpack.make(name: 'mybuildpack', stack: existing_stack.name, filename: nil, enabled: false)}

          let(:job_options) {{name: 'mybuildpack', stack: existing_stack.name, file: zipfile2, opts: new_buildpack_options,
            upgrade_buildpack_guid: existing_buildpack.guid,
            action: VCAP::CloudController::Jobs::Runtime::BuildpackInstallerOptionsFactory::UPGRADE_BUILDPACK}}

          it 'updates an existing buildpack' do
            job.perform

            buildpack2 = Buildpack.find(name: 'mybuildpack', stack: existing_stack.name)
            expect(buildpack2).to_not be_nil
            expect(buildpack2.enabled).to be false
            expect(buildpack2.filename).to end_with(File.basename(zipfile2))
            expect(buildpack2.key).to_not eql(existing_buildpack.key)
          end

          context 'but that buildpack exists and is locked' do
            let(:existing_stack) {Stack.make(name: 'stack-1')}
            let(:existing_buildpack) {Buildpack.make(name: 'lockedbuildpack', stack: existing_stack.name, locked: true)}

            it 'does not update a locked buildpack' do
              job.perform

              buildpack2 = Buildpack.find(name: 'lockedbuildpack')
              expect(buildpack2).to eql(existing_buildpack)
            end
          end
        end


        it 'knows its job name' do
          expect(job.job_name_in_configuration).to equal(:buildpack_installer)
        end

        context 'when the job raises an exception' do
          let(:error) {StandardError.new('same message')}
          let(:logger) {double(:logger)}

          before do
            allow(Steno).to receive(:logger).and_return(logger)
            allow(logger).to receive(:info).and_raise(error) # just a way to trigger an exception when calling #perform
            allow(logger).to receive(:error)
          end

          it 'logs the exception and re-raises the exception' do
            expect {job.perform}.to raise_error(error, 'same message')
            expect(logger).to have_received(:error).with(/Buildpack .* failed to install or update/)
          end
        end

        context 'when uploading the buildpack fails' do
          before do
            allow_any_instance_of(UploadBuildpack).to receive(:upload_buildpack).and_raise
          end

          context 'with a new buildpack' do
            it 'does not create a buildpack and re-raises the error' do
              expect {
                expect {
                  job.perform
                }.to raise_error(RuntimeError)
              }.to_not change {Buildpack.count}
            end
          end

          context 'with a new buildpack and stack' do
            it 'does not create a new stack and re-raises the error' do
              expect {
                expect {
                  job.perform
                }.to raise_error(RuntimeError)
              }.to_not change {Stack.count}
            end
          end

          context 'with an existing buildpack' do
            let(:existing_stack) {Stack.make(name: 'stack-1')}
            let!(:existing_buildpack) {Buildpack.make(name: 'mybuildpack', stack: existing_stack.name)}
            it 'does not update any values on the buildpack and re-raises the error' do
              expect {
                job.perform
              }.to raise_error(RuntimeError)

              expect(Buildpack.find(name: 'mybuildpack')).to eql(existing_buildpack)
            end
          end
        end
      end
    end
  end
end

=begin
- fail cases:
 - locked buildpack does nothing
 - on upload error upgrade: 'plode
 - on upload error create: clean up then 'plode
 - caught exception handling

- happy
 - enabled/unlocked:
    - create case
    - upgrade case
=end
