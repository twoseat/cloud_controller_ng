require 'spec_helper'
require 'messages/app_update_message'

module VCAP::CloudController
  RSpec.describe AppUpdateMessage do
    describe 'validations' do
      context 'when unexpected keys are requested' do
        let(:params) { { unexpected: 'foo' } }

        it 'is not valid' do
          message = AppUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:base]).to include("Unknown field(s): 'unexpected'")
        end
      end

      context 'when name is not a string' do
        let(:params) { { name: 32.77 } }

        it 'is not valid' do
          message = AppUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors_on(:name)).to include('must be a string')
        end
      end

      context 'when we have more than one error' do
        let(:params) { { name: 3.5, unexpected: 'foo' } }

        it 'is not valid' do
          message = AppUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.count).to eq(2)
          expect(message.errors.full_messages).to match_array([
            'Name must be a string',
            "Unknown field(s): 'unexpected'"
          ])
        end
      end
      describe 'lifecycle' do
        context 'when lifecycle is provided' do
          let(:params) do
            {
              name: 'some_name',
              lifecycle: {
                type: 'buildpack',
                data: {
                  buildpacks: ['java'],
                  stack: 'cflinuxfs2'
                }
              }
            }
          end

          it 'is valid' do
            message = AppUpdateMessage.new(params)
            expect(message).to be_valid
          end
        end

        context 'when lifecycle data is provided' do
          let(:params) do
            {
              lifecycle: {
                type: 'buildpack',
                data: {
                  buildpacks: [123],
                  stack: 324
                }
              }
            }
          end

          it 'must provide a valid buildpack value' do
            message = AppUpdateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors_on(:lifecycle)).to include('Buildpacks can only contain strings')
          end

          it 'must provide a valid stack name' do
            message = AppUpdateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors_on(:lifecycle)).to include('Stack must be a string')
          end
        end

        context 'when data is not provided' do
          let(:params) do
            { lifecycle: { type: 'buildpack' } }
          end

          it 'is not valid' do
            message = AppUpdateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors_on(:lifecycle_data)).to include('must be a hash')
          end
        end

        context 'when lifecycle is not provided' do
          let(:params) do
            {
              name: 'some_name',
            }
          end

          it 'does not supply defaults' do
            message = AppUpdateMessage.new(params)
            expect(message).to be_valid
            expect(message.lifecycle).to eq(nil)
          end
        end

        context 'when lifecycle type is not provided' do
          let(:params) do
            {
              lifecycle: {
                data: {}
              }
            }
          end

          it 'is not valid' do
            message = AppUpdateMessage.new(params)
            expect(message).to_not be_valid

            expect(message.errors_on(:lifecycle_type)).to include('must be a string')
          end
        end

        context 'when lifecycle data is not a hash' do
          let(:params) do
            {
              lifecycle: {
                type: 'buildpack',
                data: 'potato'
              }
            }
          end

          it 'is not valid' do
            message = AppUpdateMessage.new(params)
            expect(message).to_not be_valid

            expect(message.errors_on(:lifecycle_data)).to include('must be a hash')
          end
        end
      end
      describe 'metadata' do
        context 'when labels are valid' do
          let(:params) do
            {
              "metadata": {
                "labels": {
                  "potato": 'mashed',
                }
              }
            }
          end

          it 'is valid' do
            message = AppUpdateMessage.new(params)
            expect(message).to be_valid
          end

          it 'builds a message with access to the labels' do
            message = AppUpdateMessage.new(params)
            expect(message.labels).to include("potato": 'mashed')
            expect(message.labels.size).to equal(1)
          end
        end

        context 'when labels are not a hash' do
          let(:params) do
            {
              "metadata": {
                "labels": 'potato',
              }
            }
          end
          it 'is invalid' do
            message = AppUpdateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors_on(:metadata)).to include("'labels' is not a hash")
          end
        end

        context 'when label keys are invalid' do
          context 'when the key contains one invalid character' do
            it 'loops through and tries each bad character' do
              (32.chr..126.chr).to_a.reject { |c| /[\w\-\.\_]/.match(c) }.each do |c|
                params = {
                  "metadata": {
                    "labels": {
                      'potato' + c => 'mashed',
                      c => 'fried'
                    }
                  }
                }
                message = AppUpdateMessage.new(params)
                expect(message).not_to be_valid
                expect(message.errors_on(:metadata)).to include("label key 'potato#{c}' contains invalid characters")
              end
            end
          end

          context 'when the first or last letter is not alphanumeric' do
            let(:params) do
              {
                "metadata": {
                  "labels": {
                    '-a' => 'value1',
                    'a-' => 'value2',
                    '-' => 'value3',
                    '.a' => 'value5',
                    _a: 'value4',
                  }
                }
              }
            end
            it 'is invalid' do
              message = AppUpdateMessage.new(params)
              expect(message).not_to be_valid
              expect(message.errors_on(:metadata)).to include("label key '-a' starts or ends with invalid characters")
            end
          end

          context 'when the label key is exactly 63 characters' do
            let(:params) do
              {
                "metadata": {
                  "labels": {
                    'a' * AppUpdateMessage::MAX_LABEL_SIZE => 'value2',
                  }
                }
              }
            end
            it 'is valid' do
              message = AppUpdateMessage.new(params)
              expect(message).to be_valid
            end
          end

          context 'when the label key is greater than 63 characters' do
            let(:params) do
              {
                "metadata": {
                  "labels": {
                    'b' * (AppUpdateMessage::MAX_LABEL_SIZE + 1) => 'value3',
                  }
                }
              }
            end
            it 'is invalid' do
              message = AppUpdateMessage.new(params)
              expect(message).not_to be_valid
              expect(message.errors_on(:metadata)).to include("label key '#{'b' * 8}...' is greater than #{AppUpdateMessage::MAX_LABEL_SIZE} characters")
            end
          end
        end
        context 'when label values are invalid'
      end
    end
  end
end
