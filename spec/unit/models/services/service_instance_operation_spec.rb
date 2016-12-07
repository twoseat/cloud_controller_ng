require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ServiceInstanceOperation, type: :model do
    let(:updated_at_time) { Time.now }
    let(:created_at_time) { Time.now }
    let(:operation_attributes) do
      {
        state: 'in progress',
        description: '50% all the time',
        type: 'create',
        proposed_changes: {
          name: 'pizza',
          service_plan_guid: '1800-pizza',
        },
      }
    end

    let(:operation) { ServiceInstanceOperation.make(operation_attributes) }
    before do
      operation.this.update(updated_at: updated_at_time, created_at: created_at_time)
      operation.reload
    end

    describe '#to_hash' do
      it 'includes the type, state, description, and updated at' do
        expect(operation.to_hash).to include({
          'state' => 'in progress',
          'description' => '50% all the time',
          'type' => 'create'
        })

        expect(operation.to_hash['updated_at'].to_i).to eq(updated_at_time.to_i)
        expect(operation.to_hash['created_at'].to_i).to eq(created_at_time.to_i)
      end
    end

    describe '#proposed_changes' do
      it 'should correctly serialize & deserialize JSON' do
        expected_value = operation_attributes[:proposed_changes].stringify_keys
        expect(operation.reload.proposed_changes).to eq(expected_value)
      end
    end

    describe 'updating attributes' do
      it 'updates the attributes of the service instance operation' do
        new_attributes = {
          state: 'finished'
        }
        operation.update_attributes(new_attributes)
        expect(operation.state).to eq 'finished'
      end
    end

    describe 'validations' do
      describe 'broker_provided_operation' do
        it 'can be smaller than 10k' do
          operation.broker_provided_operation = '.' * 10000
          expect(operation).to be_valid
        end

        it 'cannot be larger than 10k' do
          operation.broker_provided_operation = '.' * 11000
          expect(operation).not_to be_valid
        end
      end
    end
  end
end
