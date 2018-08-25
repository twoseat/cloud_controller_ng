
module VCAP::CloudController
  module Jobs
    module Runtime
      class BuildpackInstallerOptionsFactory
        CREATE_BUILDPACK = 'create'.freeze
        UPGRADE_BUILDPACK = 'upgrade'.freeze

        class DuplicateInstallError < StandardError;
        end
        class StacklessBuildpackIncompatibilityError < StandardError;
        end

        def self.plan(name, file, opts, existing_plan: []) # this should be a set of some kind?
          detected_stack = VCAP::CloudController::Buildpacks::StackNameExtractor.extract_from_file(file)

          found_buildpacks = Buildpack.where(name: name).all
          if found_buildpacks.empty?
            return {
              name: name,
              stack: detected_stack,
              file: file,
              options: opts,
              action: CREATE_BUILDPACK,
            }
          end

          # this clearly not right but we need to test multiples to get the right behavior
          found_buildpack = found_buildpacks.first

          if found_buildpack.stack == detected_stack && existing_plan.include?(found_buildpack)
            raise DuplicateInstallError.new
          end

          if found_buildpack.stack && detected_stack.nil?
            raise StacklessBuildpackIncompatibilityError.new 'Existing buildpack must be upgraded with a buildpack that has a stack.'
          end

          # upgrading from nil, but we've already planned to upgrade the nil entry
          if found_buildpack.stack.nil? && detected_stack && existing_plan.include?(found_buildpack)
            return {
              name: name,
              stack: detected_stack,
              file: file,
              options: opts,
              action: CREATE_BUILDPACK,
            }
          end

          return {
            name: name,
            stack: detected_stack,
            file: file,
            options: opts,
            upgrade_buildpack_guid: found_buildpack.guid,
            action: UPGRADE_BUILDPACK,
          }
        end
      end
    end
  end
end
