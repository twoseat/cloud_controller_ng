module VCAP::CloudController
  module Jobs
    module Runtime
      class BuildpackInstallerFactory
        class DuplicateInstallError < StandardError
        end
        class StacklessBuildpackIncompatibilityError < StandardError
        end

        def initialize
          @existing_plan = []
        end

        def plan(name, file, options)
          detected_stack = VCAP::CloudController::Buildpacks::StackNameExtractor.extract_from_file(file)

          found_buildpacks = Buildpack.where(name: name).all
          if found_buildpacks.empty?
            return VCAP::CloudController::Jobs::Runtime::CreateBuildpackInstaller.new({
              name: name,
              stack: detected_stack,
              file: file,
              options: options
            })
          end

          # this clearly not right but we need to test multiples to get the right behavior
          found_buildpack = found_buildpacks.first

          if found_buildpack.stack == detected_stack && @existing_plan.include?(found_buildpack)
            raise DuplicateInstallError.new
          end

          if found_buildpack.stack && detected_stack.nil?
            raise StacklessBuildpackIncompatibilityError.new 'Existing buildpack must be upgraded with a buildpack that has a stack.'
          end

          # upgrading from nil, but we've already planned to upgrade the nil entry
          if found_buildpack.stack.nil? && detected_stack && @existing_plan.include?(found_buildpack)
            return VCAP::CloudController::Jobs::Runtime::CreateBuildpackInstaller.new({
              name: name,
              stack: detected_stack,
              file: file,
              options: options
            })
          end

          @existing_plan << found_buildpack

          VCAP::CloudController::Jobs::Runtime::UpdateBuildpackInstaller.new({
            name: name,
            stack: detected_stack,
            file: file,
            options: options,
            upgrade_buildpack_guid: found_buildpack.guid
          })

        end
      end
    end
  end
end

