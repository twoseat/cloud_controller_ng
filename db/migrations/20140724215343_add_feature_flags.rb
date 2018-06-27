Sequel.migration do
  change do
    create_table :feature_flags do
      Migration.common(self, :feature_flag)

      String :name, null: false
      Boolean :enabled, null: false

      index :name, unique: true
    end
  end
end
