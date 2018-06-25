require 'spec_helper'

RSpec.describe 'Separate user specified commands from detected commands', isolation: :truncation do
  let(:tmp_migrations_dir) { Dir.mktmpdir }

  before do
    FileUtils.cp(
      File.join(DBMigrator::SEQUEL_MIGRATIONS, '20180625223112_separate_user_specified_commands.rb'),
      tmp_migrations_dir,
    )
  end

  let!(:app_1) { VCAP::CloudController::AppModel.make(guid: 'a-with-web-process', name: 'app_with_web_process') }
  let!(:droplet_1) { VCAP::CloudController::DropletModel.make(process_types: {'web' => 'web_command'}, app: app_1)}
  let!(:droplet_2) { VCAP::CloudController::DropletModel.make(app: app_1) }
  let!(:process_1) {VCAP::CloudController::ProcessModelFactory.make(app: app_1, type: 'web', command: 'web_command')}
  let!(:process_2) {VCAP::CloudController::ProcessModelFactory.make(app: app_1, type: 'console', command: 'console_command')}
  let!(:process_3) {VCAP::CloudController::ProcessModelFactory.make(app: app_1, type: 'rake', command: nil)}

  before do
    app_1.update(droplet: droplet_1)
  end

  # race conditions
  # lots of data!

  context 'current droplet' do
    it 'sets command to null on processes that match' do
      Sequel::Migrator.run(VCAP::CloudController::AppModel.db, tmp_migrations_dir, table: :my_fake_table)
      expect(process_1.reload.command).to be_nil
      expect(process_2.reload.command).to eq('console_command')
      expect(process_3.reload.command).to be_nil
    end
  end

  context 'command matches an older droplet' do
    let!(:droplet_3) { VCAP::CloudController::DropletModel.make(process_types: {'console' => 'console_command'}, app: app_1)}

    it 'does not change the command' do
      Sequel::Migrator.run(VCAP::CloudController::AppModel.db, tmp_migrations_dir, table: :my_fake_table)
      expect(process_1.reload.command).to be_nil
      expect(process_2.reload.command).to eq('console_command')
      expect(process_3.reload.command).to be_nil
    end
  end

  context 'when the current droplet has nil process types' do
    let!(:droplet_1) { VCAP::CloudController::DropletModel.make(process_types: nil, app: app_1)}

    it 'does not change the command' do
      Sequel::Migrator.run(VCAP::CloudController::AppModel.db, tmp_migrations_dir, table: :my_fake_table)
      expect(process_1.reload.command).to eq('web_command')
      expect(process_2.reload.command).to eq('console_command')
      expect(process_3.reload.command).to be_nil
    end
  end

  context 'when the current droplet has malformed process types' do
    let!(:droplet_1) { VCAP::CloudController::DropletModel.make(process_types: {old: 'foo'}, app: app_1)}

    before do
      VCAP::CloudController::DropletModel.db[:droplets].where(guid: droplet_1.guid).update(process_types: '{} {bad json')
    end


    it 'does not change the command' do
      expect {
        Sequel::Migrator.run(VCAP::CloudController::AppModel.db, tmp_migrations_dir, table: :my_fake_table)
      }.to_not raise_error
      expect(process_1.reload.command).to eq('web_command')
      expect(process_2.reload.command).to eq('console_command')
      expect(process_3.reload.command).to be_nil
    end
  end
end
