require 'spec_helper'

module VCAP::CloudController
  RSpec.describe InstallBuildpacks do
    describe 'installs buildpacks' do
      let(:installer) {InstallBuildpacks.new(TestConfig.config_instance)}

      let(:enqueuer) {instance_double(Jobs::Enqueuer)}
      let(:job_factory) {instance_double(Jobs::Runtime::BuildpackInstallerFactory)}
      let(:install_buildpack_config) do
        {
          install_buildpacks: [
            {
              'name' => 'buildpack1',
              'package' => 'mybuildpackpkg'
            },
          ]
        }
      end

      before do
        TestConfig.override(install_buildpack_config)

        allow(Buildpacks::StackNameExtractor).to receive(:extract_from_file)
        allow(installer.logger).to receive(:error)
        allow(Jobs::Runtime::BuildpackInstallerFactory).to receive(:new).and_return(job_factory)
      end

      describe 'installing buildpacks' do
        let(:canary_job) {double(:canary_job, perform: nil)}
        let(:enqueued_job1) {double(:enqueued_job1, perform: nil)}
        let(:enqueued_job2) {double(:enqueued_job2, perform: nil)}

        context 'where there are no buildpacks to install' do
          let(:install_buildpack_config) {{install_buildpacks: []}}

          it 'does nothing and does not raise any errors' do
            expect {
              installer.install(TestConfig.config_instance.get(:install_buildpacks))
            }.to_not raise_error
          end
        end

        context 'when there are multiple buildpacks' do
          before do
            expect(Dir).to receive(:[]).with('/var/vcap/packages/mybuildpackpkg/*.zip').
              and_return(['abuildpack.zip'])
            expect(File).to receive(:file?).with('abuildpack.zip').
              and_return(true)
            expect(Dir).to receive(:[]).with('/var/vcap/packages/myotherpkg/*.zip').
              and_return(['otherbp.zip'])
            expect(File).to receive(:file?).with('otherbp.zip').
              and_return(true)
            expect(Dir).to receive(:[]).with('/var/vcap/packages/myotherpkg2/*.zip').
              and_return(['otherbp2.zip'])
            expect(File).to receive(:file?).with('otherbp2.zip').
              and_return(true)

            TestConfig.config[:install_buildpacks].concat [
              {'name' => 'buildpack2', 'package' => 'myotherpkg'},
              {'name' => 'buildpack3', 'package' => 'myotherpkg2'},
            ]


            buildpack1_fields = [{name: 'buildpack1', file: 'abuildpack.zip', options: {}}]
            allow(job_factory).to receive(:plan).with('buildpack1', buildpack1_fields).and_return([canary_job])
            buildpack2_fields = [{name: 'buildpack2', file: 'otherbp.zip', options: {}}]
            allow(job_factory).to receive(:plan).with('buildpack2', buildpack2_fields).and_return([enqueued_job1])
            buildpack3_fields = [{name: 'buildpack3', file: 'otherbp2.zip', options: {}}]
            allow(job_factory).to receive(:plan).with('buildpack3', buildpack3_fields).and_return([enqueued_job2])
            allow(Jobs::Enqueuer).to receive(:new).and_return(enqueuer)
          end

          it 'tries to install the first buildpack in-process (canary)' do
            expect(canary_job).to receive(:perform).once

            expect(enqueuer).to receive(:enqueue).twice
            expect(enqueued_job1).not_to receive(:perform)
            expect(enqueued_job2).not_to receive(:perform)

            installer.install(TestConfig.config_instance.get(:install_buildpacks))
          end

          context 'when the canary successfully installs' do
            it 'enqueues the rest of the buildpack install jobs' do
              allow(canary_job).to receive(:perform)

              expect(Jobs::Enqueuer).to receive(:new).with(enqueued_job1, queue: instance_of(Jobs::LocalQueue)).ordered.and_return(enqueuer)
              expect(Jobs::Enqueuer).to receive(:new).with(enqueued_job2, queue: instance_of(Jobs::LocalQueue)).ordered.and_return(enqueuer)

              expect(enqueuer).to receive(:enqueue).twice

              installer.install(TestConfig.config_instance.get(:install_buildpacks))
            end
          end

          context 'when the canary does not survive' do
            it 'does NOT enqueue any of the buildpack install jobs and raises an error' do
              allow(canary_job).to receive(:perform).and_raise 'BOOM'

              expect(Jobs::Enqueuer).not_to receive(:new)

              expect {
                installer.install(TestConfig.config_instance.get(:install_buildpacks))
              }.to raise_error 'BOOM'
            end
          end
        end
      end

      it 'logs an error when no buildpack zip file is found' do
        expect(Dir).to receive(:[]).with('/var/vcap/packages/mybuildpackpkg/*.zip').and_return([])
        expect(installer.logger).to receive(:error).with(/No file found for the buildpack/)

        installer.install(TestConfig.config_instance.get(:install_buildpacks))
      end

      context 'when no buildpacks defined' do
        it 'succeeds without failure' do
          installer.install(nil)
        end
      end

      context 'override file location' do
        let(:install_buildpack_config) do
          {
            install_buildpacks: [
              {
                'name' => 'buildpack1',
                'package' => 'mybuildpackpkg',
                'file' => 'another.zip',
              },
            ]
          }
        end

        it 'uses the file override' do
          # call install
          # verify that job_factory.plan was called with the right file
          expect(File).to receive(:file?).with('another.zip').and_return(true)
          expect(job_factory).to receive(:plan).with('buildpack1', [{name: 'buildpack1', file: 'another.zip', options: {}}])

          installer.install(TestConfig.config_instance.get(:install_buildpacks))
        end

        it 'fails when no buildpack zip file is found' do
          expect(installer.logger).to receive(:error).with(/File not found: another.zip/)

          installer.install(TestConfig.config_instance.get(:install_buildpacks))
        end

        it 'succeeds when no package is specified' do
          TestConfig.config[:install_buildpacks][0].delete('package')
          expect(File).to receive(:file?).with('another.zip').and_return(true)
          expect(job_factory).to receive(:plan).with('buildpack1', [{name: 'buildpack1', file: 'another.zip', options: {}}])

          installer.install(TestConfig.config_instance.get(:install_buildpacks))
        end
      end

      context 'missing required values' do
        it 'fails when no package is specified' do
          TestConfig.config[:install_buildpacks][0].delete('package')
          expect(installer.logger).to receive(:error).with(/A package or file must be specified/)

          installer.install(TestConfig.config_instance.get(:install_buildpacks))
        end

        it 'fails when no name is specified' do
          TestConfig.config[:install_buildpacks][0].delete('name')
          expect(installer.logger).to receive(:error).with(/A name must be specified for the buildpack/)

          installer.install(TestConfig.config_instance.get(:install_buildpacks))
        end
      end

      describe 'additional options' do
        let(:install_buildpack_config) do
          {
            install_buildpacks: [
              {
                'name' => 'buildpack1',
                'package' => 'mybuildpackpkg',
                'enabled' => true,
                'locked' => false,
                'position' => 5,
              },
            ]
          }
        end

        it 'has a valid config' do
          TestConfig.config[:nginx][:instance_socket] = 'mysocket'

          expect {Config.new(TestConfig.config)}.not_to raise_error
        end

        it 'passes optional attributes to the job factory' do
          expect(Dir).to receive(:[]).
            with('/var/vcap/packages/mybuildpackpkg/*.zip').
            and_return(['abuildpack.zip'])
          expect(File).to receive(:file?).
            with('abuildpack.zip').
            and_return(true)

          expect(job_factory).to receive(:plan).
            with('buildpack1',
              [{name: 'buildpack1',
                file: 'abuildpack.zip',
                options: {
                  enabled: true,
                  locked: false,
                  position: 5
                }}]
            )

          installer.install(TestConfig.config_instance.get(:install_buildpacks))

          expect(installer.logger).to_not have_received(:error)

        end
      end
    end
  end
end
