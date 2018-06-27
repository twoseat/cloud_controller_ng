require 'spec_helper'

module CloudController
  RSpec.describe ServicePlanAccess, type: :access do
    subject(:access) { ServicePlanAccess.new(Security::AccessContext.new) }
    let(:user) { CloudController::User.make }
    let(:service) { CloudController::Service.make }
    let(:object) { CloudController::ServicePlan.make(service: service) }

    before { set_current_user(user) }

    it_behaves_like :admin_full_access
    it_behaves_like :admin_read_only_access

    context 'for a logged in user (defensive)' do
      it_behaves_like :read_only_access
    end

    context 'a user that isnt logged in (defensive)' do
      let(:user) { nil }

      it_behaves_like :no_access
    end

    context 'any user using client without cloud_controller.read' do
      before { set_current_user(user, scopes: []) }

      it_behaves_like :no_access
    end
  end
end
