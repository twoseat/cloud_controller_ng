require 'spec_helper'

RSpec.describe 'Broker API Versions' do
  let(:spec_sha) do
    {
      'broker_api_v2.0_spec.rb' => '2c0603144df3d0bc5a0ecc0b47f5397a',
      'broker_api_v2.10_spec.rb' => '7701e6169e0a3488c40e5ab836829b59',
      'broker_api_v2.11_spec.rb' => '28de5d2805534794f7841bb6d2defc34',
      'broker_api_v2.12_spec.rb' => 'c3c48c6e5faa98f3e37b862522f97828',
      'broker_api_v2.13_spec.rb' => '4bbb8fad12d07e5cd87544d9442af859',
      'broker_api_v2.1_spec.rb' => '0ec44d6d5306df08165cc26ca28cf84c',
      'broker_api_v2.2_spec.rb' => '5c8f3aa67ec53e860c13618fcdd76676',
      'broker_api_v2.3_spec.rb' => '29bfb7b97eeb00160a99f45ab7b0b4bc',
      'broker_api_v2.4_spec.rb' => '999396d28d74e7e66a2eb88296b1b75a',
      'broker_api_v2.5_spec.rb' => 'c2a6740a0d5e177a21804936750cefa3',
      'broker_api_v2.6_spec.rb' => '65c11374b0916458cb2e01af6a407b58',
      'broker_api_v2.7_spec.rb' => '17130a672623fcd3bc76e22a60142304',
      'broker_api_v2.8_spec.rb' => '780dcfed65fc74dd69427f58baeb19f8',
      'broker_api_v2.9_spec.rb' => '1d6e7f8561c11a3609ec3f813acbd13e',
    }
  end
  let(:digester) { Digester.new(algorithm: Digest::MD5) }

  it 'verifies that there is a broker API test for each minor version' do
    stub_request(:get, 'http://broker-url/v2/catalog').
      with(basic_auth: ['username', 'password']).
      to_return do |request|
      @version = request.headers['X-Broker-Api-Version']
      { status: 200, body: {}.to_json }
    end

    post('/v2/service_brokers',
      { name: 'broker-name', broker_url: 'http://broker-url', auth_username: 'username', auth_password: 'password' }.to_json,
      admin_headers)

    major_version, current_minor_version = @version.split('.').map(&:to_i)
    broker_api_specs = (0..current_minor_version).to_a.map do |minor_version|
      "broker_api_v#{major_version}.#{minor_version}_spec.rb"
    end

    expect(broker_api_specs.length).to be > 0

    current_directory = File.dirname(__FILE__)
    current_directory_list = Dir.entries(current_directory)

    actual_checksums = {}
    broker_api_specs.each do |spec|
      expect(current_directory_list).to include(spec)

      filename = "#{current_directory}/#{spec}"
      actual_checksums[spec] = digester.digest(File.read(filename))
    end

    # These tests are not meant to be changed since they help ensure backwards compatibility.
    # If you do need to update this test, you can update the expected sha
    expect(actual_checksums).to eq(spec_sha)
  end
end
