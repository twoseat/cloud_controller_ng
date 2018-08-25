module VCAP::CloudController
  module Jobs
    module Runtime
      class BuildpackInstaller < VCAP::CloudController::Jobs::CCJob

        attr_accessor :name, :file, :opts, :guid_to_upgrade, :stack

        # private_class_method :new
        def initialize(job_options)
          @name = job_options[:name]
          @file = job_options[:file]
          @opts = job_options[:opts]
          @stack = job_options[:stack]
          @guid_to_upgrade = job_options[:upgrade_buildpack_guid]
          @action = job_options[:action]
        end

        # perform refactor: make separate objs for upgrae/create and share upload & error code

        def perform #
          logger = Steno.logger('cc.background')
          logger.info "Installing buildpack #{name}"

          buildpack = Buildpack.find(guid: guid_to_upgrade)
          puts guid_to_upgrade

          # perhaps this behaviour belongs in the options factory?
          if buildpack&.locked
            logger.info "Buildpack #{name} locked, not updated"
            return
          end

          created = false
          if buildpack.nil? # this should change
            buildpacks_lock = Locking[name: 'buildpacks']
            buildpacks_lock.db.transaction do
              buildpacks_lock.lock!
              Stack.create(name: stack) if Stack.find(name: stack).nil? # wat do if fail to upload?
              buildpack = Buildpack.create(name: name, stack: stack)
            end
            created = true
          end

          begin
            buildpack_uploader.upload_buildpack(buildpack, file, File.basename(file))
          rescue => e
            if created
              buildpack.destroy
            end
            raise e
          end

          buildpack.update(opts)
          logger.info "Buildpack #{name} installed or updated"
        rescue => e
          logger.error("Buildpack #{name} failed to install or update. Error: #{e.inspect}")
          raise e
        end

        def max_attempts
          1
        end

        def job_name_in_configuration
          :buildpack_installer
        end

        def buildpack_uploader
          buildpack_blobstore = CloudController::DependencyLocator.instance.buildpack_blobstore
          UploadBuildpack.new(buildpack_blobstore)
        end
      end
    end
  end
end
