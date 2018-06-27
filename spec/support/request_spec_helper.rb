module RequestSpecHelper
  ENV['RACK_ENV'] = 'test'

  def app
    test_config     = TestConfig.config_instance
    request_metrics = CloudController::Metrics::RequestMetrics.new
    CloudController::RackAppBuilder.new.build test_config, request_metrics
  end
end
