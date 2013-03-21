module TentValidator
  class ResponseExpectation
    require 'tent-validator/response_expectation/assertion'
    require 'tent-validator/response_expectation/base_validator'
    require 'tent-validator/response_expectation/header_validator'

    attr_accessor :header_validator
    def initialize(validator, options = {}, &block)
      initialize_headers(options.delete(:headers))
    end

    def initialize_headers(expected_headers)
      return unless expected_headers
      self.header_validator = HeaderValidator.new(expected_headers)
    end
  end
end
