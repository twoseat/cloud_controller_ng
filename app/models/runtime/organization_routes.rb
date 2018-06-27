class OrganizationRoutes
  def initialize(organization)
    @organization = organization
  end

  def count
    dataset.count
  end

  private

  def dataset
    CloudController::Route.dataset.join(:spaces, id: :space_id).
      where(spaces__organization_id: @organization.id)
  end
end
