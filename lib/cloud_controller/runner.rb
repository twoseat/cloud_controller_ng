require 'steno'
require 'optparse'
require 'i18n'
require 'i18n/backend/fallbacks'
require 'cloud_controller/uaa/uaa_token_decoder'
require 'cloud_controller/uaa/uaa_verification_keys'
require 'loggregator_emitter'
require 'loggregator'
require 'cloud_controller/rack_app_builder'
require 'cloud_controller/metrics/periodic_updater'
require 'cloud_controller/metrics/request_metrics'
require 'puma'
require 'puma/configuration'

module VCAP::CloudController
  class Runner
    attr_reader :config_file, :insert_seed_data

    def initialize(argv)
      @argv = argv

      # default to production. this may be overridden during opts parsing
      ENV['NEW_RELIC_ENV'] ||= 'production'

      parse_options!
      parse_config

      setup_i18n

      @log_counter = Steno::Sink::Counter.new
    end

    def setup_i18n
      CloudController::Errors::ApiError.setup_i18n(
        Dir[File.expand_path('../../../vendor/errors/i18n/*.yml', __FILE__)],
        'en_US',
      )
    end

    def logger
      setup_logging
      @logger ||= Steno.logger('cc.runner')
    end

    def options_parser
      @parser ||= OptionParser.new do |opts|
        opts.on('-c', '--config [ARG]', 'Configuration File') do |opt|
          @config_file = opt
        end
      end
    end

    def deprecation_warning(message)
      puts message
    end

    def parse_options!
      options_parser.parse!(@argv)
      raise 'Missing config' unless @config_file.present?
    rescue
      raise options_parser.to_s
    end

    def parse_config
      @config = Config.load_from_file(@config_file, context: :api)
    rescue Membrane::SchemaValidationError => ve
      raise "ERROR: There was a problem validating the supplied config: #{ve}"
    rescue => e
      raise "ERROR: Failed loading config from file '#{@config_file}': #{e}"
    end

    def run!
      create_pidfile

      begin
        start_cloud_controller

        request_metrics = VCAP::CloudController::Metrics::RequestMetrics.new(statsd_client)
        gather_periodic_metrics

        builder = RackAppBuilder.new
        app = builder.build(@config, request_metrics)

        start_puma_server(app)
      rescue => e
        logger.error "Encountered error: #{e}\n#{e.backtrace.join("\n")}"
        raise e
      end
    end

    def gather_periodic_metrics
      logger.info('starting periodic metrics updater')
      periodic_updater.setup_updates
    end

    def trap_signals
      %w(TERM INT QUIT).each do |signal|
        trap(signal) do
          logger.warn("Caught signal #{signal}")
          stop!
        end
      end

      trap('USR1') do
        logger.warn('Collecting diagnostics')
        collect_diagnostics
      end
    end

    def stop!
      stop_puma_server
      logger.info('Stopping EventMachine')
    end

    private

    def start_cloud_controller
      setup_logging
      setup_db
      @config.configure_components

      setup_loggregator_emitter
      @config.set(:external_host, VCAP::HostSystem.new.local_ip(@config.get(:local_route)))
    end

    def create_pidfile
      pid_file = VCAP::PidFile.new(@config.get(:pid_filename))
      pid_file.unlink_at_exit
    rescue
      raise "ERROR: Can't create pid file #{@config.get(:pid_filename)}"
    end

    def setup_logging
      return if @setup_logging
      @setup_logging = true

      StenoConfigurer.new(@config.get(:logging)).configure do |steno_config_hash|
        steno_config_hash[:sinks] << @log_counter
      end
    end

    def setup_db
      db_logger = Steno.logger('cc.db')
      DB.load_models(@config.get(:db), db_logger)
    end

    def setup_loggregator_emitter
      if @config.get(:loggregator) && @config.get(:loggregator, :router)
        Loggregator.emitter = LoggregatorEmitter::Emitter.new(@config.get(:loggregator, :router), 'cloud_controller', 'API', @config.get(:index))
        Loggregator.logger = logger
      end
    end

    def start_puma_server(app)
      foobar = Puma::Rack::Builder.app(app)

      host = if @config.get(:nginx, :use_nginx)
               @config.get(:nginx, :instance_socket)
             else
               "tcp://#{@config.get(:external_host)}:#{@config.get(:external_port)}"
             end

      puma_configuration = Puma::Configuration.new do |config|
        config.workers 3
        config.bind host
        config.app foobar
        config.preload_app!
      end

      @puma_server = Puma::Launcher.new(puma_configuration)

      trap_signals

      # @puma_server.persistent_timeout = @config.get(:request_timeout_in_seconds)
      @puma_server.run
    end

    def stop_puma_server
      logger.info('Stopping Puma Server.')
      @puma_server.stop if @puma_server
    end

    def periodic_updater
      @periodic_updater ||= VCAP::CloudController::Metrics::PeriodicUpdater.new(
        Time.now.utc,
        @log_counter,
        Steno.logger('cc.api'),
        [
          VCAP::CloudController::Metrics::StatsdUpdater.new(statsd_client)
        ])
    end

    def statsd_client
      return @statsd_client if @statsd_client

      logger.info("configuring statsd server at #{@config.get(:statsd_host)}:#{@config.get(:statsd_port)}")
      Statsd.logger = Steno.logger('statsd.client')
      @statsd_client = Statsd.new(@config.get(:statsd_host), @config.get(:statsd_port))
    end

    def collect_diagnostics
      @diagnostics_dir ||= @config.get(:directories, :diagnostics)

      file = VCAP::CloudController::Diagnostics.new.collect(@diagnostics_dir)
      logger.warn("Diagnostics written to #{file}")
    rescue => e
      logger.warn("Failed to capture diagnostics: #{e}")
    end
  end
end
