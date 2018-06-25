Sequel.migration do
  up do
    processes = self[:processes].exclude(command: nil)

    processes.each do |process|
      app = self[:apps].where(guid: process[:app_guid]).first
      current_droplet = self[:droplets].where(guid: app[:droplet_guid]).first
      process_types_as_string = current_droplet[:process_types]

      begin
      process_types = JSON.parse(process_types_as_string)
      rescue JSON::ParserError => e
        puts e
      end

      if process_types && process_types[process[:type]] == process[:command]
        self[:processes].where(guid: process[:guid]).update(command: nil)
      end
    end
  end
  down do
  end
end
