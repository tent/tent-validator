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
    end

    class Expectation
      class Anything
        def ==(other)
          true
        end
      end

      class Matcher
        def initialize(expected)
          @expected = expected
        end

        def match(actual, expected=@expected)
          case expected
          when Regexp
            !!expected.match(actual.to_s)
          when Range
            expected.include?(actual)
          else
            actual == expected
          end
        end
      end

      class JSONMatcher < Matcher
        def match(actual, expected=@expected)
          case expected
          when Hash
            if actual.kind_of?(String)
              actual = Yajl::Parser.parse(actual)
            end

            res = true
            expected.each_pair do |k,v|
              unless match(actual[k.to_s], v)
                res = false
              end
            end
            res
          else
            super
          end
        end
      end

      attr_reader :expected_body, :expected_headers, :expected_status

      def initialize(options)
        @expected_body = options.delete(:body) || anything
        @expected_headers = options.delete(:headers) || anything
        @expected_status = options.delete(:status) || (200...300)
        @options = options
      end

      def anything
        Anything.new
      end

      def validate(response)
        validate_body(response) && validate_headers(response) && validate_status(response)
      end

      private

      def validate_body(response)
        return true if expected_body.kind_of?(Anything)

        if @options[:list]
          if response.body.kind_of?(String)
            response_body = Yajl::Parser.parse(response.body)
          else
            response_body = response.body
          end
          return false unless response_body.kind_of?(Array)
          !response_body.map { |i| _validate_body(i) }.find { |i| !i }
        else
          _validate_body(response.body)
        end
      end

      def _validate_body(response_body)
        case expected_body
        when Regexp
          !!expected_body.match(response_body)
        when Hash
          JSONMatcher.new(expected_body).match(response_body)
        else
          expected_body == response_body
        end
      end

      def validate_headers(response)
        return true if expected_headers.kind_of?(Anything)
        expected_headers.inject(true) do |memo, (k,v)|
          unless Matcher.new(v).match(response.headers[k.to_s.downcase])
            memo = false
          end
          memo
        end
      end

      def validate_status(response)
        return true if expected_status.kind_of?(Anything)
        Matcher.new(expected_status).match(response.status)
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
        JSON::Validator.validate(schema, response.body, @schema_options)
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
          next memo if expectation.expected_headers.kind_of?(Expectation::Anything)
          memo.merge(expectation.expected_headers)
        }
      end

      def expected_response_body
        expectations.inject({}) { |memo, expectation|
          next memo if expectation.expected_body.kind_of?(Expectation::Anything)
          next expectation.expected_body if expectation.expected_body.kind_of?(String)
          memo.merge(expectation.expected_body)
        }
      end

      def expected_response_status
        if expectation = expectations.find { |expectation| expectation.expected_status != (200...300) }
          expectation.expected_status
        elsif expectation = expectations.first
          expectation.expected_status
        end
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

    def expect(options)
      @expectations << Expectation.new(options.merge(list: @options[:list]))
    end

    def validate(options)
      validate_headers
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
  end
end
