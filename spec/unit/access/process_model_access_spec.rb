require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ProcessModelAccess, type: :access do
    subject(:access) { ProcessModelAccess.new(Security::AccessContext.new) }
    let(:token) { { 'scope' => ['cloud_controller.read', 'cloud_controller.write'] } }
    let(:user) { VCAP::CloudController::User.make }
    let(:org) { VCAP::CloudController::Organization.make }
    let(:space) { VCAP::CloudController::Space.make(organization: org) }
    let(:object) { VCAP::CloudController::ProcessModelFactory.make(space: space) }

    let(:flag) { FeatureFlag.make(name: 'app_scaling', enabled: false) }

    index_table = {
      unauthenticated: true,
      reader_and_writer: true,
      reader: true,
      writer: true,

      admin: true,
      admin_read_only: true,
      global_auditor: true,
    }

    read_table = {
      unauthenticated: false,
      reader_and_writer: true,
      reader: true,
      writer: false,

      admin: true,
      admin_read_only: true,
      global_auditor: true,
    }

    write_table = {
      unauthenticated: false,
      reader_and_writer: false,
      reader: false,
      writer: false,

      admin: true,
      admin_read_only: false,
      global_auditor: false,
    }

    restricted_read_table = read_table.clone.merge({

    })

    restricted_write_table = write_table.clone.merge({
      space_developer: false,
    })

    it_behaves_like('an access control', :index, index_table)
    it_behaves_like('an access control', :read, read_table)
    it_behaves_like('an access control', :read_env, restricted_read_table)

    describe 'when the app is in a suspended org' do
      before(:each) do
        org.status = VCAP::CloudController::Organization::SUSPENDED
        org.save
      end

      describe 'when the "app_scaling" feature flag is enabled' do
        before(:each) do
          flag.enabled = true
          flag.save
        end

        it_behaves_like('an access control', :create, restricted_write_table)
        it_behaves_like('an access control', :delete, restricted_write_table)
        it_behaves_like('an access control', :read_for_update, restricted_write_table)
        it_behaves_like('an access control', :update, restricted_write_table)

        [:instances, :memory, :disk_quota].each do |param|
          describe "when setting #{param}" do
            let(:op_params) do
              params = {}
              params[param] = 'foo'
              params
            end

            it_behaves_like('an access control', :read_for_update, restricted_write_table)
          end
        end

        describe 'when setting something else' do
          let(:op_params) { { foo: 'bar' } }

          it_behaves_like('an access control', :read_for_update, restricted_write_table)
        end
      end

      describe 'when the "app_scaling" feature flag is disabled' do
        it_behaves_like('an access control', :read_for_update, restricted_write_table)

        [:instances, :memory, :disk_quota].each do |param|
          describe "when setting #{param}" do
            let(:op_params) do
              params = {}
              params[param] = 'foo'
              params
            end

            it_behaves_like('an access control', :read_for_update, restricted_write_table)
          end
        end

        describe 'when setting something else' do
          let(:op_params) { { foo: 'bar' } }

          it_behaves_like('an access control', :read_for_update, write_table)
        end
      end
    end

    describe 'when the app is not in a suspended org' do
      describe 'when the "app_scaling" feature flag is enabled' do
        before(:each) do
          flag.enabled = true
          flag.save
        end

        it_behaves_like('an access control', :create, write_table)
        it_behaves_like('an access control', :delete, write_table)
        it_behaves_like('an access control', :read_for_update, write_table)
        it_behaves_like('an access control', :update, write_table)

        [:instances, :memory, :disk_quota].each do |param|
          describe "when setting #{param}" do
            let(:op_params) do
              params = {}
              params[param] = 'foo'
              params
            end

            it_behaves_like('an access control', :read_for_update, write_table)
          end
        end

        describe 'when setting something else' do
          let(:op_params) { { foo: 'bar' } }

          it_behaves_like('an access control', :read_for_update, write_table)
        end
      end

      describe 'when the "app_scaling" feature flag is disabled' do
        it_behaves_like('an access control', :read_for_update, write_table)

        [:instances, :memory, :disk_quota].each do |param|
          describe "when setting #{param}" do
            let(:op_params) do
              params = {}
              params[param] = 'foo'
              params
            end

            it_behaves_like('an access control', :read_for_update, restricted_write_table)
          end
        end

        describe 'when setting something else' do
          let(:op_params) { { foo: 'bar' } }

          it_behaves_like('an access control', :read_for_update, write_table)
        end
      end
    end
  end
end
