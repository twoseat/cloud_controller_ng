module VCAP::CloudController
  class RotateDatabaseKey
    class << self

      def perform
        current_key_label = Encryptor.current_encryption_key_label
        apps = AppModel.order(:id).exclude(encryption_key_label: current_key_label)
        apps.paged_each do |app|
          app.environment_variables = app.environment_variables # This actually changes values on the model due to the encryption/decryption logic
          app.save
        end
      end

      def perform_for_klass(klass)

      end
    end
  end
end
