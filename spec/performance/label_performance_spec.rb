require 'benchmark'
require 'spec_helper'
require 'rails_helper'

RSpec.describe AppsV3Controller, type: :controller, isolation: :truncation do
  describe '#index' do
    before do
      set_current_user_as_admin
    end

    after do
      puts
      puts accumulated_results.join("\n")
    end

    let(:initial_apps) { 10 }
    let(:growth_factor) { 10 }
    let(:envs) { %w(dev, test, prod) }
    let(:tiers) { %w(backend, frontend) }
    let(:accumulated_results) { [] }

    (1..3).each do |j|
      describe "#{10 * (10 ** j)} app instances" do

        let(:number_of_apps) { initial_apps * (growth_factor ** j) }
        let(:cb_codes) { Array.new(number_of_apps / 3).fill(SecureRandom.uuid) }
        before do
          VCAP::CloudController::AppModel.db.transaction do
            number_of_apps.times do |i|
              app = VCAP::CloudController::AppModel.make
              VCAP::CloudController::AppLabel.make(app: app, label_key: 'environment', label_value: envs.sample)
              VCAP::CloudController::AppLabel.make(app: app, label_key: 'chargeback_code', label_value: cb_codes.sample)
              VCAP::CloudController::AppLabel.make(app: app, label_key: 'tiers', label_value: tiers.sample) if i % 2 == 0
              Array(1..25).sample.times do |k|
                VCAP::CloudController::AppLabel.make(app: app, label_key: SecureRandom.uuid, label_value: SecureRandom.uuid)
              end
            end
          end
        end

        it 'measures performance' do
          chargeback_code = cb_codes.sample

          perfs = Benchmark.bmbm do |bm|
            bm.report('equality +cardinality:') do
              get :index, params: { label_selector: "chargeback_code=#{chargeback_code}" }
            end
            bm.report('inequality +cardinality:') do
              get :index, params: { label_selector: "chargeback_code!=#{chargeback_code}" }
            end

            bm.report('existence --cardinality:') do
              get :index, params: { label_selector: 'tier' }
            end
            bm.report('!existence --cardinality:') do
              get :index, params: { label_selector: '!tier' }
            end

            bm.report('in -cardinality:') do
              get :index, params: { label_selector: 'environment in (test, dev)' }
            end
            bm.report('notin -cardinality:') do
              get :index, params: { label_selector: 'environment notin (test, dev)' }
            end
          end

          number_of_labels = VCAP::CloudController::AppLabel.count
          perfs.map { |perf| accumulated_results << "#{number_of_apps},#{number_of_labels},#{perf.label},#{perf.real}" }
        end
      end
    end
  end
end
