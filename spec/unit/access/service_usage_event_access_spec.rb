require 'spec_helper'

module CloudController
  RSpec.describe ServiceUsageEventAccess, type: :access do
    subject(:access) { ServiceUsageEventAccess.new(Security::AccessContext.new) }
    let(:user) { CloudController::User.make }
    let(:object) { CloudController::ServiceUsageEvent.make }

    before { set_current_user(user) }

    it_behaves_like :admin_read_only_access

    context 'an admin' do
      include_context :admin_setup

      it_behaves_like :full_access
      it { is_expected.to allow_op_on_object :reset, CloudController::ServiceUsageEvent }
    end

    context 'a user that is not an admin (defensive)' do
      it_behaves_like :no_access

      it { is_expected.not_to allow_op_on_object :index, CloudController::ServiceUsageEvent }
      it { is_expected.not_to allow_op_on_object :reset, CloudController::ServiceUsageEvent }
    end

    context 'a user that isnt logged in (defensive)' do
      let(:user) { nil }

      it_behaves_like :no_access
      it { is_expected.not_to allow_op_on_object :index, CloudController::ServiceUsageEvent }
      it { is_expected.not_to allow_op_on_object :reset, CloudController::ServiceUsageEvent }
    end
  end
end
