require 'spec_helper'

RSpec.describe 'Separate user specified commands from detected commands', isolation: :truncation do
  let(:tmp_migrations_dir) { Dir.mktmpdir }

  before do
    FileUtils.cp(
      File.join(DBMigrator::SEQUEL_MIGRATIONS, '20180625223112_separate_user_specified_commands.rb'),
      tmp_migrations_dir,
    )
  end

  let!(:app_1) { VCAP::CloudController::AppModel.make(name: 'app_with_web_process') }
  let!(:droplet_1) { VCAP::CloudController::DropletModel.make(process_types: {'web' => 'web_command'}, app: app_1)}
  let!(:droplet_2) { VCAP::CloudController::DropletModel.make(app: app_1) }
  let!(:process_1) {VCAP::CloudController::ProcessModelFactory.make(app: app_1, type: 'web', command: 'web_command')}
  let!(:process_2) {VCAP::CloudController::ProcessModelFactory.make(app: app_1, type: 'console', command: 'console_command')}
  let!(:process_3) {VCAP::CloudController::ProcessModelFactory.make(app: app_1, type: 'rake', command: nil)}

  before do
    app_1.update(droplet: droplet_1)
  end

  # race conditions

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

    it 'nulls out commands that match current droplet but not commands that match older droplet' do
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

  context 'when the app does not have a current droplet' do
    let!(:droplet_1) { VCAP::CloudController::DropletModel.make(process_types: {old: 'foo'}, app: app_1)}

    before do
      app_1.update(droplet: nil)
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

  context 'with a lot of data' do
    let(:n) {10}
    before do
      VCAP::CloudController::AppModel.db.transaction do
        n.times do |i|
          app_model = VCAP::CloudController::AppModel.make(name: 'app_with_web_process')
          droplet_model = VCAP::CloudController::DropletModel.make(process_types: {'web' => 'web_command'}, app_guid: app_model.guid)
          VCAP::CloudController::DropletModel.make(app_guid: app_model.guid)
          VCAP::CloudController::ProcessModelFactory.make(app: app_model, type: 'web', command: 'web_command')
          VCAP::CloudController::ProcessModelFactory.make(app: app_model, type: 'console', command: 'console_command')
          VCAP::CloudController::ProcessModelFactory.make(app: app_model, type: 'rake', command: nil)
          app_model.reload
          app_model.update(droplet_guid: droplet_model.guid)
        end
      end
    end

    it 'times' do
      require 'benchmark'
      time = Benchmark.realtime do
        Sequel::Migrator.run(VCAP::CloudController::AppModel.db, tmp_migrations_dir, table: :my_fake_table)
      end

      expect(time).to eq(10)
    end
  end
end
