module TentValidator
  class ResponseExpectation
    require 'tent-validator/response_expectation/assertion'
    require 'tent-validator/response_expectation/base_validator'
    require 'tent-validator/response_expectation/header_validator'
    require 'tent-validator/response_expectation/status_validator'

    attr_accessor :header_validator, :status_validator
    def initialize(validator, options = {}, &block)
      initialize_headers(options.delete(:headers))
      initialize_status(options.delete(:status))
    end

    def initialize_headers(expected_headers)
      return unless expected_headers
      self.header_validator = HeaderValidator.new(expected_headers)
    end

    def initialize_status(expected_status)
      return unless expected_status
      self.status_validator = StatusValidator.new(expected_status)
    end
  end
end
