module TentValidator
  class ResponseExpectation
    require 'tent-validator/response_expectation/results'
    require 'tent-validator/response_expectation/assertion'
    require 'tent-validator/response_expectation/base_validator'
    require 'tent-validator/response_expectation/header_validator'
    require 'tent-validator/response_expectation/status_validator'
    require 'tent-validator/response_expectation/json_validator'
    require 'tent-validator/response_expectation/schema_validator'

    attr_accessor :status_validator
    def initialize(validator, options = {}, &block)
      @validator, @block = validator, block
      initialize_headers(options.delete(:headers))
      initialize_status(options.delete(:status))
      initialize_schema(options.delete(:schema))
    end

    def initialize_headers(expected_headers)
      return unless expected_headers
      self.header_validators << HeaderValidator.new(expected_headers)
    end

    def initialize_status(expected_status)
      return unless expected_status
      self.status_validator = StatusValidator.new(expected_status)
    end

    def initialize_schema(expected_schema)
      return unless expected_schema
      schema_validators << SchemaValidator.new(expected_schema)
    end

    def json_validators
      @json_validators ||= []
    end

    def schema_validators
      @schema_validators ||= []
    end

    def header_validators
      @header_validators ||= []
    end

    def expectations
      [status_validator].compact + header_validators + schema_validators + json_validators
    end

    def expect_properties(properties)
      json_validators << JsonValidator.new(properties)
    end

    def expect_schema(expected_schema, path=nil)
      schema_validators << SchemaValidator.new(expected_schema, path)
    end

    def expect_headers(expected_headers)
      header_validators << HeaderValidator.new(expected_headers)
    end

    def run
      return unless @block
      response = instance_eval(&@block)
      Results.new(response, validate(response))
    end

    def validate(response)
      expectations.map { |expectation| expectation.validate(response) }
    end

    def respond_to_method_missing?(method)
      @validator.respond_to?(method)
    end

    def method_missing(method, *args, &block)
      if respond_to_method_missing?(method)
        @validator.send(method, *args, &block)
      else
        super
      end
    end
  end
end
