require 'spec_helper'
require 'cloud_controller/diego/lifecycle_protocol'

module CloudController::Diego
  RSpec.describe LifecycleProtocol do
    describe '.protocol_for_type' do
      subject(:protocol) { LifecycleProtocol.protocol_for_type(type) }

      context 'with BUILDPACK' do
        let(:type) { CloudController::Lifecycles::BUILDPACK }

        it 'returns a buildpack lifecycle protocol' do
          expect(protocol).to be_a(CloudController::Diego::Buildpack::LifecycleProtocol)
        end
      end

      context 'with DOCKER' do
        let(:type) { CloudController::Lifecycles::DOCKER }

        it 'returns a buildpack lifecycle protocol' do
          expect(protocol).to be_a(CloudController::Diego::Docker::LifecycleProtocol)
        end
      end
    end
  end
end
