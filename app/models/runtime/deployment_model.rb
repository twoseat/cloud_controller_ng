module CloudController
  class DeploymentModel < Sequel::Model(:deployments)
    DEPLOYING_STATE = 'DEPLOYING'.freeze

    many_to_one :app,
      class: 'CloudController::AppModel',
      primary_key: :guid,
      key: :app_guid,
      without_guid_generation: true

    many_to_one :droplet,
      class: 'CloudController::DropletModel',
      key: :droplet_guid,
      primary_key: :guid,
      without_guid_generation: true

    many_to_one :webish_process,
      class: 'CloudController::ProcessModel',
      key: :webish_process_guid,
      primary_key: :guid,
      without_guid_generation: true
  end
end
