require 'spec_helper'

module VCAP::CloudController
  RSpec.describe DB do
    describe '.connect'

    describe '.database_parts_from_connection' do
      let(:db_string) {"foo://#{userinfo}#{hostinfo}/#{database_name}" }
      let(:database_name) { "stuff" }
      let(:userinfo) { "#{username}#{passwordinfo}@" }
      let(:username) { 'chuck' }
      let(:passwordinfo) { ':superpassword' }
      let(:hostinfo) { "somehost#{portinfo}" }
      let(:portinfo) { ':5432' }

      context 'when all fields are present' do
        let(:expected_hash) do {
          adapter: 'foo',
          host: 'somehost',
          port: 5432,
          user: 'chuck',
          password: 'superpassword',
          database: 'stuff',
        }
        end
        it 'should convert to a useful hash' do
          expect(DB.database_parts_from_connection(db_string)).to eq(expected_hash)
        end
      end
      context 'when there is no user or password' do
        it 'should convert to a hash with some nil items'
      end
      context 'when there is a user but no password' do
        it 'should convert to a hash with some nil items'
      end
      context 'when the password has been http-encoded' do
        it 'should unescape the password field'
      end
      context 'when no port is present' do
        it 'should convert to a hash with some nil items'
      end
    end
  end
end
