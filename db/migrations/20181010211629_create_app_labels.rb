Sequel.migration do
  change do
    create_table :app_labels do
      VCAP::Migration.common(self)

      String :app_guid, null: false
      String :label_key, null: false, case_insensitive: false
      String :label_value, null: true, case_insensitive: false

      index [:label_key, :label_value], unique: false
    end
  end
end
