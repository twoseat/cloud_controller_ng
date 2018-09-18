Sequel.migration do
  change do
    create_table :encryption_key_sentinels do
      VCAP::Migration.common(self)
      String :expected_value, size: 255
      String :encrypted_value, size: 255
      String :encryption_key_label, size: 255, unique: true
      String :salt, size: 255
    end
  end
end
