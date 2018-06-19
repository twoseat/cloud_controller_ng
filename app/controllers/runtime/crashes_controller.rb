module VCAP::CloudController
  class CrashesController < RestController::ModelController
    def self.dependencies
      [:instances_reporters]
    end

    path_base 'apps'
    model_class_name :ProcessModel
    self.not_found_exception_name = 'AppNotFound'

    get "#{path_guid}/crashes", :crashes

    def crashes(guid)
      process           = find_guid_and_validate_access(:read, guid)
      crashed_instances = instances_reporters.crashed_instances_for_app(process)
      MultiJson.dump(crashed_instances)
    end

    protected

    attr_reader :instances_reporters

    def inject_dependencies(dependencies)
      super
      @instances_reporters = dependencies[:instances_reporters]
    end

    def find_guid(guid, model=ProcessModel)
      if model == ProcessModel
        obj = AppModel.find(guid: guid).try(:web_process)
        raise self.class.not_found_exception(guid, AppModel) if obj.nil?
        obj
      else
        super
      end
    end
  end
end
