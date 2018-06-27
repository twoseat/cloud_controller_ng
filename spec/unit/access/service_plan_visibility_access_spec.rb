require 'spec_helper'

module CloudController
  RSpec.describe ServicePlanVisibilityAccess, type: :access do
    subject(:access) { ServicePlanVisibilityAccess.new(Security::AccessContext.new) }

    let(:user) { CloudController::User.make }
    let(:service) { CloudController::Service.make }
    let(:org) { CloudController::Organization.make }
    let(:service_plan) { CloudController::ServicePlan.make(service: service) }

    let(:object) { CloudController::ServicePlanVisibility.make(organization: org, service_plan: service_plan) }

    before { set_current_user(user) }

    it_behaves_like :admin_full_access
    it_behaves_like :admin_read_only_access

    context 'for a logged in user (defensive)' do
      it_behaves_like :no_access
    end

    context 'a user that isnt logged in (defensive)' do
      let(:user) { nil }

      it_behaves_like :no_access
    end

    context 'organization manager (defensive)' do
      before { org.add_manager(user) }

      it_behaves_like :no_access
    end

    context 'organization auditor (defensive)' do
      before { org.add_auditor(user) }

      it_behaves_like :no_access
    end

    context 'organization user (defensive)' do
      before { org.add_user(user) }

      it_behaves_like :no_access
    end
  end
end
