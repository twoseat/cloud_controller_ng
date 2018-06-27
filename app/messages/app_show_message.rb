require 'messages/base_message'

module CloudController
  class AppShowMessage < BaseMessage
    register_allowed_keys [:include]

    validates_with NoAdditionalParamsValidator
    validates_with IncludeParamValidator, valid_values: ['space']
  end
end
