require 'spec_helper'
require 'actions/space_create'

module CloudController
  RSpec.describe SpaceCreate do
    describe 'create' do
      let(:org) { CloudController::Organization.make }
      let(:perm_client) { instance_spy(CloudController::Perm::Client) }

      it 'creates a space' do
        message = CloudController::SpaceCreateMessage.new(name: 'my-space')
        space = SpaceCreate.new(perm_client: perm_client).create(org, message)

        expect(space.organization).to eq(org)
        expect(space.name).to eq('my-space')
      end

      context 'when a model validation fails' do
        it 'raises an error' do
          errors = Sequel::Model::Errors.new
          errors.add(:blork, 'is busted')
          expect(CloudController::Space).to receive(:create).
            and_raise(Sequel::ValidationFailed.new(errors))

          message = CloudController::SpaceCreateMessage.new(name: 'foobar')
          expect {
            SpaceCreate.new(perm_client: perm_client).create(org, message)
          }.to raise_error(SpaceCreate::Error, 'blork is busted')
        end

        context 'when it is a uniqueness error' do
          let(:name) { 'Olsen' }

          before do
            CloudController::Space.create(organization: org, name: name)
          end

          it 'raises a human-friendly error' do
            message = CloudController::SpaceCreateMessage.new(name: name)
            expect {
              SpaceCreate.new(perm_client: perm_client).create(org, message)
            }.to raise_error(SpaceCreate::Error, 'Name must be unique per organization')
          end
        end
      end
    end
  end
end
