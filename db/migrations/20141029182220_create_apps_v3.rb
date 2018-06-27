Sequel.migration do
  change do
    create_table :apps_v3 do
      Migration.common(self)
      String :space_guid
      index :space_guid
    end
  end
end
