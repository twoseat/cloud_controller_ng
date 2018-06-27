class BackgroundJobEnvironment
  def initialize(config)
    @config = config
    @log_counter = Steno::Sink::Counter.new

    CloudController::StenoConfigurer.new(config.get(:logging)).configure do |steno_config_hash|
      steno_config_hash[:sinks] << @log_counter
    end
  end

  def setup_environment
    CloudController::DB.load_models(@config.get(:db), Steno.logger('cc.background'))
    @config.configure_components

    yield if block_given?
  end
end
