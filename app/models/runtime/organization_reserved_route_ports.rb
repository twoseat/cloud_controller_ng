module CloudController
  class OrganizationReservedRoutePorts
    def initialize(organization)
      @organization = organization
    end

    def count
      dataset.count
    end

    private

    def dataset
      CloudController::Route.dataset.
        join(:spaces, id: :space_id).
        join(:domains, id: :routes__domain_id).
        where(spaces__organization_id: @organization.id).
        exclude("domains__router_group_guid": nil).
        exclude("routes__port": nil)
    end
  end
end
