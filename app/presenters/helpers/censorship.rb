module VCAP::CloudController
  module Presenters
    module Censorship
      PRIVATE_DATA_HIDDEN = 'PRIVATE DATA HIDDEN'.freeze
      PRIVATE_DATA_HIDDEN_BRACKETS = '[PRIVATE DATA HIDDEN]'.freeze

      REDACTED_MESSAGE      = '[PRIVATE DATA HIDDEN]'.freeze
      REDACTED_LIST_MESSAGE = '[PRIVATE DATA HIDDEN IN LISTS]'.freeze

      REDACTED_CREDENTIAL = '***'.freeze

      CENSORED_MESSAGE ||= 'PRIVATE DATA HIDDEN'.freeze

      REDACTED = '[REDACTED]'.freeze
      REDACTED_2 = 'REDACTED'.freeze
    end
  end
end
