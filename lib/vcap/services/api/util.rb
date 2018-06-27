# Copyright (c) 2009-2011 VMware, Inc.
module Services
  module Api
  end
end

class Services::Api::Util
  class << self
    def parse_label(label)
      raise ArgumentError.new('Invalid label') unless label.match?(/-/)
      name, _, version = label.rpartition(/-/)
      [name, version]
    end
  end
end
