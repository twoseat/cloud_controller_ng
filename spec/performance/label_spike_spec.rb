require 'spec_helper'
require 'rails_helper'

RSpec.configure do |c|
  c.filter_run_when_matching :focus
end

RSpec.describe AppsV3Controller, type: :controller do
  describe '#index' do
    before do
    set_current_user_as_admin
  end
    context 'when we have some labels' do
      let!(:app1) { VCAP::CloudController::AppModel.make(guid: 'guid1', name: 'app1')}
      let!(:app2) { VCAP::CloudController::AppModel.make(guid: 'guid2', name: 'app2')}
      let!(:app3) { VCAP::CloudController::AppModel.make(guid: 'guid3', name: 'app3')}
      let!(:app4) { VCAP::CloudController::AppModel.make(guid: 'guid4', name: 'app4')}

      before do
        VCAP::CloudController::AppLabel.make(app: app1, label_key: 'environment', label_value: 'production')
        VCAP::CloudController::AppLabel.make(app: app1, label_key: 'tier', label_value: 'frontend')

        VCAP::CloudController::AppLabel.make(app: app2, label_key: 'environment', label_value: 'production')
        VCAP::CloudController::AppLabel.make(app: app2, label_key: 'tier', label_value: 'backend')

        VCAP::CloudController::AppLabel.make(app: app3, label_key: 'potato', label_value: 'fries')

        VCAP::CloudController::AppLabel.make(app: app4, label_key: 'environment', label_value: 'testing')
      end

      it 'handles a single =' do
        get :index, params: { label_selector: 'environment=production'}
        expect(response.status).to eq(200), response.body
        resources = parsed_body['resources']
        expect(resources.map{|x| x['guid']}).to match_array([app1.guid, app2.guid])
      end

      fit 'handles a single !=' do
        get :index, params: { label_selector: 'environment!=production'}
        expect(response.status).to eq(200), response.body
        resources = parsed_body['resources']
        expect(resources.map{|x| x['guid']}).to match_array([app3.guid, app4.guid])
      end

      it 'handles multiple =s' do
        get :index, params: { label_selector: 'environment=production,tier=frontend'}
        expect(response.status).to eq(200), response.body
        resources = parsed_body['resources']
        expect(resources.map{|x| x['guid']}).to match_array([app1.guid])
      end

      it 'handles another multiple =s' do
        get :index, params: { label_selector: 'environment=production,tier=backend'}
        expect(response.status).to eq(200), response.body
        resources = parsed_body['resources']
        expect(resources.map{|x| x['guid']}).to match_array([app2.guid])
      end

      it 'handles mixed = and !=' do
        get :index, params: { label_selector: 'environment!=production,potato=fries'}
        expect(response.status).to eq(200), response.body
        resources = parsed_body['resources']
        expect(resources.map{|x| x['guid']}).to match_array([app3.guid])
      end

      it 'handles multiple !=s' do
        get :index, params: { label_selector: 'environment!=production,potato!=russet,talk!=action'}
        expect(response.status).to eq(200), response.body
        resources = parsed_body['resources']
        expect(resources.map{|x| x['guid']}).to match_array([app3.guid, app4.guid])
      end

      it 'handles a single set' do
        get :index, params: { label_selector: 'environment in (production, testing)'}
        expect(response.status).to eq(200), response.body
        resources = parsed_body['resources']
        expect(resources.map{|x| x['guid']}).to match_array([app1.guid, app2.guid, app4.guid])
      end

      it 'handles a not in set' do
        get :index, params: { label_selector: 'environment notin (production, development)'}
        expect(response.status).to eq(200), response.body
        resources = parsed_body['resources']
        expect(resources.map{|x| x['guid']}).to match_array([app3.guid, app4.guid])
      end

      it 'handles existence' do
        get :index, params: { label_selector: 'environment'}
        expect(response.status).to eq(200), response.body
        resources = parsed_body['resources']
        expect(resources.map{|x| x['guid']}).to match_array([app1.guid, app2.guid, app4.guid])
      end

      it 'handles negated existence' do
        get :index, params: { label_selector: '!environment'}
        expect(response.status).to eq(200), response.body
        resources = parsed_body['resources']
        expect(resources.map{|x| x['guid']}).to match_array([app3.guid])
      end
    end
  end
end
