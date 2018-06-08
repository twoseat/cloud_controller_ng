require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RotateDatabaseKey do
    let(:app) { AppModel.make }
    let(:app_new_key_label) { AppModel.make }
    let(:env_vars) { { 'foo' => 'bar' } }
    let(:env_vars_other) { { 'baz' => 'qux' } }

    describe '#perform' do
      before do
        Encryptor.current_encryption_key_label = 'old'
        Encryptor.database_encryption_keys = { 'old' => 'old-key', 'new' => 'new-key' }
        app.environment_variables = env_vars
        app.save
        Encryptor.current_encryption_key_label = 'new'
        app_new_key_label.environment_variables = env_vars_other
        app_new_key_label.save

        allow(VCAP::CloudController::Encryptor).to receive(:encrypt).and_call_original
        allow(VCAP::CloudController::Encryptor).to receive(:decrypt).and_call_original
      end

      it 'changes the key label of each model' do
        RotateDatabaseKey.perform

        expect(app.reload.encryption_key_label).to eq('new')
        end

      it 're-encrypts the value with the new key' do
        RotateDatabaseKey.perform

        expect(VCAP::CloudController::Encryptor).to have_received(:decrypt).
          with(app.environment_variables_without_encryption, app.salt, 'old').at_least(:once)
        expect(VCAP::CloudController::Encryptor).to have_received(:encrypt).
          with(JSON.dump(env_vars), app.salt).at_least(:once)
        expect(app.environment_variables).to eq(env_vars)
      end

      it 'does not re-encrypt values that are already encrypted with the new label' do
        RotateDatabaseKey.perform

        expect(VCAP::CloudController::Encryptor).not_to have_received(:decrypt).
          with(app_new_key_label.environment_variables_without_encryption, app_new_key_label.salt, 'new')
        expect(VCAP::CloudController::Encryptor).not_to have_received(:encrypt).
          with(JSON.dump(env_vars_other), app_new_key_label.salt)
        expect(app_new_key_label.environment_variables).to eq(env_vars_other)
      end
    end
  end
end
