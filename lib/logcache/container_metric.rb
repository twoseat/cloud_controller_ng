module Logcache
  class ContainerMetrics
    attr_reader :instanceIndex, :cpuPercentage, :memoryBytes, \
    :diskBytes
    def initialize(instanceIndex, cpuPercentage, memoryBytes, \
    diskBytes)
      @instanceIndex = instanceIndex
      @cpuPercentage = cpuPercentage
      @memoryBytes = memoryBytes
      @diskBytes = diskBytes
    end
  end
end

module Logcache
  class ContainerMetricsWrapper
    def initialize(container_metric)
      @container_metric = container_metric
    end

    def containerMetric
      return @container_metric
    end
  end

  class ContainerMetrics
    attr_reader :instanceIndex, :cpuPercentage, :memoryBytes, \
    :diskBytes

    def initialize(envelope, instanceIndex, cpuPercentage, memoryBytes, \
    diskBytes)
      @instanceIndex = instanceIndex
      @cpuPercentage = cpuPercentage
      @memoryBytes = memoryBytes
      @diskBytes = diskBytes
    end
  end
end
