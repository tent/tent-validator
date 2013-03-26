module TentValidator
  class ResponseExpectation
    require 'tent-validator/response_expectation/results'
    require 'tent-validator/response_expectation/assertion'
    require 'tent-validator/response_expectation/base_validator'
    require 'tent-validator/response_expectation/header_validator'
    require 'tent-validator/response_expectation/status_validator'
    require 'tent-validator/response_expectation/json_validator'
    require 'tent-validator/response_expectation/schema_validator'

    attr_accessor :header_validator, :status_validator, :schema_validator
    def initialize(validator, options = {}, &block)
      @block = block
      initialize_headers(options.delete(:headers))
      initialize_status(options.delete(:status))
      initialize_schema(options.delete(:schema))
    end

    def initialize_headers(expected_headers)
      return unless expected_headers
      self.header_validator = HeaderValidator.new(expected_headers)
    end

    def initialize_status(expected_status)
      return unless expected_status
      self.status_validator = StatusValidator.new(expected_status)
    end

    def initialize_schema(expected_schema)
      return unless expected_schema
      self.schema_validator = SchemaValidator.new(expected_schema)
    end

    def json_validators
      @json_validators ||= []
    end

    def expectations
      [header_validator, status_validator, schema_validator].compact + json_validators
    end

    def expect_properties(properties)
      json_validators << JsonValidator.new(properties)
    end

    def run
      return unless @block
      response = @block.call
      Results.new(response, validate(response))
    end

    def validate(response)
      expectations.map { |expectation| expectation.validate(response) }
    end
  end
end
