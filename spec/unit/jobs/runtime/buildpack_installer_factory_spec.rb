require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe BuildpackInstallerFactory do
      describe '.plan' do
        let(:name) { 'mybuildpack' }
        let(:file) { File.expand_path('../../../fixtures/good.zip', File.dirname(__FILE__)) }
        let(:opts) { { enabled: true, locked: false, position: 1 } }
        let(:factory) { BuildpackInstallerFactory.new }
        let(:job) { factory.plan(name, file, opts) }

        shared_examples_for 'passthrough parameters' do
          it 'passes through buildpack name, file, and opts' do
            expect(job.name).to eq(name)
          end
          it 'passes through opts' do
            expect(job.options).to eq(opts)
          end
          it 'passes through file' do
            expect(job.file).to eq(file)
          end
        end

        context 'there is no matching buildpack record by name' do
          before do
            allow(VCAP::CloudController::Buildpacks::StackNameExtractor).to receive(:extract_from_file).
              with(file).and_return('detected stack')
          end

          include_examples 'passthrough parameters'

          it 'plans to create the record' do
            expect(job).to be_a(CreateBuildpackInstaller)
          end

          it 'sets the stack to the detected stack' do
            expect(job.stack_name).to eq('detected stack')
          end
        end

        context 'there is an existing buildpack that matches by name' do
          context 'when the buildpack record has a stack' do
            let(:existing_stack) { Stack.make(name: 'existing stack') }
            let!(:existing_buildpack) { Buildpack.make(name: name, stack: existing_stack.name, key: 'new_key', guid: 'the guid') }

            context 'and the buildpack zip has the same stack' do
              before do
                allow(VCAP::CloudController::Buildpacks::StackNameExtractor).to receive(:extract_from_file).
                  with(file).and_return(existing_stack.name)
              end

              context 'and this buildpack is not in the plan' do

                include_examples 'passthrough parameters'

                it 'sets the stack to the matching stack' do
                  expect(job.stack_name).to eq(existing_stack.name)
                end

                it 'plans on updating that record' do
                  expect(job).to be_a(UpdateBuildpackInstaller)
                end

                it 'identifies the buildpack record to update' do
                  expect(job.guid_to_upgrade).to eq('the guid')
                end
              end

              context 'and this buildpack is in the plan' do
                before do
                  factory.plan(name, file, opts)
                end

                it 'errors' do
                  expect {
                    job
                  }.to raise_error(VCAP::CloudController::Jobs::Runtime::BuildpackInstallerFactory::DuplicateInstallError)
                end
              end
            end

            context 'and the buildpack zip does not specify stack' do
              before do
                allow(VCAP::CloudController::Buildpacks::StackNameExtractor).to receive(:extract_from_file).
                  with(file).and_return(nil)
              end

              it 'errors' do
                expect {
                  factory.plan(name, file, opts)
                }.to raise_error(VCAP::CloudController::Jobs::Runtime::BuildpackInstallerFactory::StacklessBuildpackIncompatibilityError)
              end
            end
          end

          context 'and that buildpack record has a nil stack' do
            let!(:existing_buildpack) { Buildpack.make(name: name, stack: nil, key: 'new_key', guid: 'the guid') }

            context 'and the buildpack zip also has a nil stack' do
              before do
                allow(VCAP::CloudController::Buildpacks::StackNameExtractor).to receive(:extract_from_file).
                  with(file).and_return(nil)
              end

              context 'when we are not already planning to update that buildpack record' do

                include_examples 'passthrough parameters'

                it 'plans to update' do
                  expect(job).to be_a(UpdateBuildpackInstaller)
                end

                it 'identifies the buildpack record to update' do
                  expect(job.guid_to_upgrade).to eq('the guid')
                end

                it 'leaves the stack nil' do
                  expect(job.stack_name).to be nil
                end
              end

              context 'and this buildpack is in the plan' do
                before do
                  factory.plan(name, file, opts)
                end

                it 'errors' do
                  expect {
                    job
                  }.to raise_error(VCAP::CloudController::Jobs::Runtime::BuildpackInstallerFactory::DuplicateInstallError)
                end
              end
            end

            context 'but the buildpack zip /has/ a stack' do
              before do
                allow(VCAP::CloudController::Buildpacks::StackNameExtractor).to receive(:extract_from_file).
                  with(file).and_return('manifest stack')
              end

              context 'when we have not planned to update the nil record' do

                include_examples 'passthrough parameters'

                it 'plans on updating it' do
                  expect(job).to be_a(UpdateBuildpackInstaller)
                end

                it 'gives the record to the detected stack' do
                  expect(job.stack_name).to eq 'manifest stack'
                end

                it 'identifies the buildpack record to update' do
                  expect(job.guid_to_upgrade).to eq('the guid')
                end
              end

              context 'when we are already planning to update the nil record' do
                before do
                  factory.plan(name, file, opts)
                end

                include_examples 'passthrough parameters'

                it 'it plans on creating a new record' do
                  expect(job).to be_a(CreateBuildpackInstaller)
                end

                it 'gives the record to the detected stack' do
                  expect(job.stack_name).to eq 'manifest stack'
                end
              end
            end
          end
        end
      end
    end
  end
end
