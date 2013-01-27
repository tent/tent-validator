require 'tent-schemas'
require 'json-schema'
require 'tentd/core_ext/hash/slice'

module TentValidator
  class ResponseValidator

    Error = Class.new(StandardError)
    ValidatorNotFoundError = Class.new(Error)

    class HeaderExpectation
      def initialize(header, value, options={})
        @header = header
        @value = value
        @options = options
      end

      def validate(response)
        header = response.env[:response_headers][@header.to_s]
        if @value.kind_of?(Array)
          response_header_values = header.to_s.split(@options[:split])
          (@value - response_header_values).empty?
        elsif @value.kind_of?(Regexp)
          !!(header =~ @value)
        else
          header == @value
        end
      end

      def expected_headers
        value = if @value.kind_of?(Regexp)
                  @value.source
                else
                  @value
                end
        {
          @header => value
        }
      end
    end

    class StatusExpectation
      def initialize(value)
        @value = value
      end

      def validate(response)
        if @value.kind_of?(Range)
          @value.include?(response.status)
        else
          response.status == @value
        end
      end

      def expected_status
        @value
      end
    end

    class BodyExpectation
      class DeepJsonMatcher
        def initialize(actual)
          @actual = actual
        end

        def match(expected, actual=@actual)
          case expected
          when Hash
            res = true
            expected.each_pair do |k,v|
              unless match(v, actual[k.to_s])
                res = false
              end
            end
            res
          when Regexp
            !!expected.match(actual)
          else
            expected == actual
          end
        end
      end

      def initialize(expected_fields)
        @expected_fields = expected_fields
      end

      def validate(response)
        return false unless response.body.kind_of?(Hash)
        DeepJsonMatcher.new(response.body).match(@expected_fields)
      end

      def expected_body
        @expected_fields
      end
    end

    class Result
      attr_reader :response, :context, :expectations
      attr_accessor :expectation

      SchemaNotFoundError = Class.new(StandardError)

      def initialize(params = {})
        @response = params[:response]
        @context = params[:context]
        @expectations = params[:expectations]
        @schema = params[:schema]
        @schema_options = params.slice(:list)
      end

      def passed?
        !expectations.any? { |e| !e.validate(response) } && schema_valid?
      end

      def schema
        return unless @schema
        raise SchemaNotFoundError unless schema = TentSchemas[@schema]
        schema
      end

      def schema_valid?
        return true unless schema
        JSON::Validator.fully_validate(schema, response.body, @schema_options).empty?
      end

      def as_json(options = {})
        {
          :request_headers => response.env[:request_headers],
          :request_body => response.env[:request_body],
          :request_path => response.env[:url].path,
          :request_params => parse_params(response.env[:url]),
          :request_url => response.env[:url].to_s,
          :request_method => response.env[:method].to_s.upcase,

          :response_headers => response.headers,
          :response_body => response.body,
          :response_status => response.status,
          :response_schema_errors => @schema ? JSON::Validator.fully_validate(schema, response.body, @schema_options) : [],

          :expected_response_headers => expected_response_headers,
          :expected_response_body => expected_response_body,
          :expected_response_status => expected_response_status,
          :expected_response_schema => @schema,

          :failed_headers_expectations => failed_headers_expectations,
          :failed_body_expectations => failed_body_expectations,
          :failed_status_expectations => failed_status_expectations,

          :passed => passed?,
        }
      end

      def parse_params(uri)
        return unless uri.query
        uri.query.split('&').inject({}) do |params, part|
          key, value = part.split('=')
          params[key] = value
          params
        end
      end

      private

      def expected_response_headers
        expectations.inject({}) { |memo, expectation|
          next memo unless expectation.respond_to?(:expected_headers)
          memo.merge(expectation.expected_headers)
        }
      end

      def failed_headers_expectations
        expectations.select { |expectation|
          expectation.respond_to?(:expected_headers) && !expectation.validate(response)
        }.map(&:expected_headers)
      end

      def expected_response_body
        expectations.inject({}) { |memo, expectation|
          next memo unless expectation.respond_to?(:expected_body)
          memo.merge(expectation.expected_body)
        }
      end

      def failed_body_expectations
        expectations.select { |expectation|
          expectation.respond_to?(:expected_body) && !expectation.validate(response)
        }.map(&:expected_body)
      end

      def expected_response_status
        expected_status = expectations.select { |expectation|
          expectation.respond_to?(:expected_status)
        }.map(&:expected_status)
        expected_status.size > 1 ? expected_status : expected_status.first
      end

      def failed_status_expectations
        expectations.select { |expectation|
          expectation.respond_to?(:expected_status) && !expectation.validate(response)
        }.map(&:expected_status)
      end
    end

    class << self
      attr_accessor :validators
    end

    def self.register(name)
      ResponseValidator.validators ||= {}
      ResponseValidator.validators[name.to_s] = self
    end

    def self.validate_headers(&block)
      @validate_headers ||= []
      @validate_headers.push(block)
    end

    def self.validate_status(&block)
      @validate_status ||= []
      @validate_status.push(block)
    end

    def self.validate(name, options={}, &block)
      raise ValidatorNotFoundError.new(name) unless ResponseValidator.validators && validator = ResponseValidator.validators[name.to_s]
      response = yield
      validator.new(response, block, options).validate(options)
    end

    attr_reader :response

    def initialize(response, block, options={})
      @response = response
      @block = block
      @expectations = []
      @options = options
    end

    def validate(options)
      validate_headers
      validate_status(options)
      validate_body(options[:properties])
      Result.new(
        :validator => self,
        :expectations => @expectations,
        :response => @response,
        :schema => @options[:schema],
        :list => @options[:list],
        :context => @block.binding.eval("self")
      )
    end

    private

    def validate_headers
      (self.class.class_eval { @validate_headers } || []).each do |block|
        next unless block
        instance_eval(&block)
      end
    end

    def expect_header(header, value, options={})
      @expectations << HeaderExpectation.new(header, value, options)
    end

    def validate_status(options)
      if options[:status]
        @expectations << StatusExpectation.new(options[:status])
      end

      (self.class.class_eval { @validate_status } || []).each do |block|
        next unless block
        instance_eval(&block)
      end
    end

    def expect_status(value)
      @expectations << StatusExpectation.new(value)
    end

    def validate_body(expected_fields)
      return unless expected_fields
      @expectations << BodyExpectation.new(expected_fields)
    end
  end
end
