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
    let(:growth_factor) { 2 }
    let(:envs) { %w(dev test prod) }
    let(:tiers) { %w(backend frontend) }
    let(:accumulated_results) { [] }
    let(:specific_app) { VCAP::CloudController::AppModel.make }


    (1..11).each do |j|
      describe "#{10 * (2 ** j)} app instances" do

        let(:number_of_apps) { initial_apps * (growth_factor ** j) }
        let(:cb_codes) { Array.new(number_of_apps / 3).fill{ || SecureRandom.uuid } }
        before do
          VCAP::CloudController::AppModel.db.transaction do
            number_of_apps.times do |i|
              app = VCAP::CloudController::AppModel.make
              VCAP::CloudController::AppLabel.make(app: app, label_key: 'environment', label_value: envs.sample)
              VCAP::CloudController::AppLabel.make(app: app, label_key: 'chargeback_code', label_value: cb_codes.sample)
              VCAP::CloudController::AppLabel.make(app: app, label_key: 'tier', label_value: tiers.sample) if i % 2 == 0
              Array(1..25).sample.times do |k|
                VCAP::CloudController::AppLabel.make(app: app, label_key: SecureRandom.uuid, label_value: SecureRandom.uuid)
              end
            end
            @specific_cb_code = cb_codes.sample
            VCAP::CloudController::AppLabel.make(specific_app, label_key: 'environment', label_value: 'prod')
            VCAP::CloudController::AppLabel.make(specific_app, label_key: 'tier', label_value: 'backend')
            VCAP::CloudController::AppLabel.make(specific_app, label_key: 'chargeback_code', label_value: @specific_cb_code)
          end
        end

        it 'measures performance' do
          chargeback_code = cb_codes.sample

          perfs = Benchmark.bmbm do |bm|
            bm.report('inequality +cardinality') do
              get :index, params: { label_selector: "chargeback_code!=#{chargeback_code}" }
              #puts parsed_body['resources']
            end

            bm.report('equality +cardinality') do # IS SLOW
              get :index, params: { label_selector: "chargeback_code=#{chargeback_code}" }
              #puts parsed_body['resources']
            end
            bm.report('equality miss +cardinality') do # IS SLOW
              get :index, params: { label_selector: "chargeback_code=#{SecureRandom.uuid}" }
              #puts parsed_body['resources']
            end


            bm.report('!existence --cardinality') do # IS SLOW
              get :index, params: { label_selector: '!tier' }
              #puts parsed_body['resources']
            end

            bm.report('existence --cardinality') do
              get :index, params: { label_selector: 'tier' }
              #puts parsed_body['resources']
            end


            bm.report('notin -cardinality') do # IS SLOW
              get :index, params: { label_selector: 'environment notin (test, dev)' }
              #puts parsed_body['resources']
            end
            bm.report('in -cardinality') do
              get :index, params: { label_selector: 'environment in (test, dev)' }
              #puts parsed_body['resources']
            end

            bm.report('specific composite') do
              get :index, params: { label_selector: "environment=prod,tier=backend,chargeback_code=#{@specific_cb_code}" }
              #puts parsed_body['resources']
            end
          end
          app_count = VCAP::CloudController::AppModel.count
          number_of_labels = VCAP::CloudController::AppLabel.count
          perfs.map { |perf| accumulated_results << "#{perf.label},#{app_count},#{number_of_labels},#{perf.real}" }
          open("#{Dir.home}/Documents/postgres-indexed3.csv", 'a') { |f|
            f.puts accumulated_results
          }
        end
      end
    end
  end
end
