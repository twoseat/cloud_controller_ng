module VCAP::CloudController
  class InstallBuildpacks
    attr_reader :config

    def initialize(config)
      @config = config
    end

    def install(buildpacks)
      return unless buildpacks

      job_factory = VCAP::CloudController::Jobs::Runtime::BuildpackInstallerFactory.new

      buildpack_install_jobs = []

      factory_options = []
      buildpacks.each do |bpack|
        buildpack_opts = bpack.deep_symbolize_keys

        buildpack_name = buildpack_opts.delete(:name)
        if buildpack_name.nil?
          logger.error "A name must be specified for the buildpack_opts: #{buildpack_opts}"
          next
        end

        package = buildpack_opts.delete(:package)
        buildpack_file = buildpack_opts.delete(:file)
        if package.nil? && buildpack_file.nil?
          logger.error "A package or file must be specified for the buildpack_opts: #{bpack}"
          next
        end

        buildpack_file = buildpack_zip(package, buildpack_file)
        if buildpack_file.nil?
          logger.error "No file found for the buildpack_opts: #{bpack}"
          next
        elsif !File.file?(buildpack_file)
          logger.error "File not found: #{buildpack_file}, for the buildpack_opts: #{bpack}"
          next
        end

        factory_options << {name: buildpack_name, file: buildpack_file, options: buildpack_opts}
      end

      names = factory_options.collect {|o| o[:name]}
      names.each do |name|
        buildpacks = factory_options.find_all { |o| o[:name] == name}
        puts "buildpacks for #{name}: #{buildpacks}"
        buildpack_install_jobs << job_factory.plan(name, buildpacks)
      end

      buildpack_install_jobs.flatten!

      job_classes = buildpack_install_jobs.collect {|j| j.class}
      run_canary(buildpack_install_jobs)
      enqueue_remaining_jobs(buildpack_install_jobs)
    end

    ##
    #
    # HEY NERDS!
    #
    # job_factory.plan assumes no invalid stack nils
    # job_factory.plan assumes and no repeated updates
    #  PULL up detected_stack && remove tests from below
    # Does global position matter or is it only relative to shared names
    #
    # jobs[]
    # valid_buildpacks = {}
    # if !valid_buildpacks.key?(name)
    #   valid_buildpacks[name] = []
    # end
    #
    #   if valid_buildpacks[name].size > 1 && stack == nil
    #     raise error#1 (no digressing)
    #   else if valid_buildpacks[name].any? {|bp| bp.stack == stack}
    #     raise error#2 (no double updates)
    #   else
    #     valid_buildpacks[name] << {stack, file, opts}
    #   end
    #
    # valid_buildpacks.each {|bp_name, bp_fields| jobs << factory.plan(bp_name, bp_fields) }
    #

    def logger
      @logger ||= Steno.logger('cc.install_buildpacks')
    end

    private

    def buildpack_zip(package, zipfile)
      return zipfile if zipfile
      job_dir = File.join('/var/vcap/packages', package, '*.zip')
      Dir[job_dir].first
    end

    def run_canary(jobs)
      jobs.first.perform if jobs.first
    end

    def enqueue_remaining_jobs(jobs)
      jobs.drop(1).each do |job|
        VCAP::CloudController::Jobs::Enqueuer.new(job, queue: VCAP::CloudController::Jobs::LocalQueue.new(config)).enqueue
      end
    end
  end
end
