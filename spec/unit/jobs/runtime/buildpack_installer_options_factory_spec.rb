require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe BuildpackInstallerOptionsFactory do
      describe '.plan' do
        let(:name) {'mybuildpack'}
        let(:file) {File.expand_path('../../../fixtures/good.zip', File.dirname(__FILE__))}
        let(:opts) {{enabled: true, locked: false, position: 1}}
        let(:existing_plan) {[]}
        let(:job_options) {BuildpackInstallerOptionsFactory.plan(name, file, opts, existing_plan: existing_plan)}

        shared_examples_for 'passthrough parameters' do
          it 'passes through buildpack name, file, and opts' do
            expect(job_options[:name]).to eq(name)
          end
          it 'passes through opts' do
            expect(job_options[:options]).to eq(opts)
          end
          it 'passes through file' do
            expect(job_options[:file]).to eq(file)
          end
        end

        context 'there is no matching buildpack record by name' do
          before do
            allow(VCAP::CloudController::Buildpacks::StackNameExtractor).to receive(:extract_from_file).
              with(file).and_return('detected stack')
          end

          include_examples 'passthrough parameters'

          it 'plans to create the record' do
            expect(job_options[:action]).to be BuildpackInstallerOptionsFactory::CREATE_BUILDPACK
          end

          it 'sets the stack to the detected stack' do
            expect(job_options[:stack]).to eq('detected stack')
          end
        end

        context 'there is an existing buildpack that matches by name' do
          context 'when the buildpack record has a stack' do
            let(:existing_stack) {Stack.make(name: 'existing stack')}
            let!(:existing_buildpack) {Buildpack.make(name: name, stack: existing_stack.name, key: 'new_key', guid: 'the guid')}

            context 'and the buildpack zip has the same stack' do
              before do
                allow(VCAP::CloudController::Buildpacks::StackNameExtractor).to receive(:extract_from_file).
                  with(file).and_return(existing_stack.name)
              end

              context 'and this buildpack is not in the plan' do
                let(:existing_plan) {[]}

                include_examples 'passthrough parameters'

                it 'sets the stack to the matching stack' do
                  expect(job_options[:stack]).to eq(existing_stack.name)
                end

                it 'plans on updating that record' do
                  expect(job_options[:action]).to be BuildpackInstallerOptionsFactory::UPGRADE_BUILDPACK
                end

                it 'identifies the buildpack record to update' do
                  expect(job_options[:upgrade_buildpack_guid]).to eq('the guid')
                end
              end

              context 'and this buildpack is in the plan' do
                let(:existing_plan) {[existing_buildpack]}

                it 'errors' do
                  expect {
                    job_options
                  }.to raise_error(VCAP::CloudController::Jobs::Runtime::BuildpackInstallerOptionsFactory::DuplicateInstallError)
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
                  BuildpackInstallerOptionsFactory.plan(name, file, opts)
                }.to raise_error(VCAP::CloudController::Jobs::Runtime::BuildpackInstallerOptionsFactory::StacklessBuildpackIncompatibilityError)
              end
            end
          end

          context 'and that buildpack record has a nil stack' do
            let!(:existing_buildpack) {Buildpack.make(name: name, stack: nil, key: 'new_key', guid: 'the guid')}

            context 'and the buildpack zip also has a nil stack' do
              before do
                allow(VCAP::CloudController::Buildpacks::StackNameExtractor).to receive(:extract_from_file).
                  with(file).and_return(nil)
              end

              context 'when we are not already planning to update that buildpack record' do
                let(:existing_plan) {[]}

                include_examples 'passthrough parameters'

                it 'plans to update' do
                  expect(job_options[:action]).to be BuildpackInstallerOptionsFactory::UPGRADE_BUILDPACK
                end

                it 'identifies the buildpack record to update' do
                  expect(job_options[:upgrade_buildpack_guid]).to eq('the guid')
                end

                it 'leaves the stack nil' do
                  expect(job_options[:stack]).to be nil
                end
              end

              context 'and this buildpack is in the plan' do
                let(:existing_plan) {[existing_buildpack]}

                it 'errors' do
                  expect {
                    puts job_options
                  }.to raise_error(VCAP::CloudController::Jobs::Runtime::BuildpackInstallerOptionsFactory::DuplicateInstallError)
                end
              end
            end

            context 'but the buildpack zip /has/ a stack' do
              before do
                allow(VCAP::CloudController::Buildpacks::StackNameExtractor).to receive(:extract_from_file).
                  with(file).and_return('manifest stack')
              end

              context 'when we have not planned to update the nil record' do
                let(:existing_plan) {[]}

                include_examples 'passthrough parameters'

                it 'plans on updating it' do
                  expect(job_options[:action]).to be BuildpackInstallerOptionsFactory::UPGRADE_BUILDPACK
                end

                it 'gives the record to the detected stack' do
                  expect(job_options[:stack]).to eq 'manifest stack'
                end

                it 'identifies the buildpack record to update' do
                  expect(job_options[:upgrade_buildpack_guid]).to eq('the guid')
                end
              end

              context 'when we are already planning to update the nil record' do
                let(:existing_plan) {[existing_buildpack]}

                include_examples 'passthrough parameters'

                it 'it plans on creating a new record' do
                  expect(job_options[:action]).to be BuildpackInstallerOptionsFactory::CREATE_BUILDPACK
                end

                it 'gives the record to the detected stack' do
                  expect(job_options[:stack]).to eq 'manifest stack'
                end
              end
            end
          end
        end
      end
    end
  end
end
