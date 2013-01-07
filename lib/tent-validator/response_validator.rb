module TentValidator
  class ResponseValidator

    Error = Class.new(StandardError)
    ValidatorNotFoundError = Class.new(Error)

    class Expectation
      class Anything
      end

      class JSONMatcher
        def initialize(expected)
          @expected = expected
        end

        def match(actual, expected=@expected)
          case expected
          when Regexp
            !!expected.match(actual)
          when Hash
            if actual.kind_of?(String)
              actual = Yajl::Parser.parse(actual)
            end

            res = true
            expected.each_pair do |k,v|
              return false unless _actual = actual[k.to_s]
              unless match(_actual, v)
                res = false
              end
            end
            res
          else
            actual == expected
          end
        end
      end

      attr_reader :expected_body, :expected_headers, :expected_status

      def initialize(options)
        @expected_body = options.delete(:body) || anything
        @expected_headers = options.delete(:headers) || anything
        @expected_status = options.delete(:status) || anything
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

        case expected_body
        when Regexp
          !!expected_body.match(response.body)
        when Hash
          JSONMatcher.new(expected_body).match(response.body)
        else
          expected_body == response.body
        end
      end

      def validate_headers(response)
        return true if expected_headers.kind_of?(Anything)
        false
      end

      def validate_status(response)
        return true if expected_status.kind_of?(Anything)
        false
      end
    end

    class Result
      attr_reader :response, :context, :expectations
      attr_accessor :expectation

      def initialize(params = {})
        @response = params[:response]
        @context = params[:context]
        @expectations = params[:expectations]
      end

      def passed?
        !@expectations.any? { |e| !e.validate(response) }
      end

      # TODO: finish filling in data
      def as_json(options = {})
        {
          :request_headers => response.env[:request_headers],
          :request_body => response.env[:request_body],
          :request_path => response.env[:url].path,
          :request_params => parse_params(response.env[:url]),
          :request_url => response.env[:url].to_s,

          :response_headers => response.headers,
          :response_body => response.body,
          :response_status => response.status,

          :expected_response_headers => nil,
          :expected_response_body => nil,
          :expected_response_status => nil,

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
    end

    class << self
      attr_accessor :validators
    end

    def self.register(name)
      ResponseValidator.validators ||= {}
      ResponseValidator.validators[name.to_s] = self
    end

    def self.validate(name, options={}, &block)
      raise ValidatorNotFoundError.new(name) unless ResponseValidator.validators && validator = ResponseValidator.validators[name.to_s]
      response = yield
      validator.new(response, block).validate(options)
    end

    attr_reader :response

    def initialize(response, block)
      @response = response
      @block = block
      @expectations = []
    end

    def expect(options)
      @expectations << Expectation.new(options)
    end

    def validate(options)
      Result.new(
        :validator => self,
        :expectations => @expectations,
        :response => @response,
        :context => @block.binding.eval("self")
      )
    end
  end
end
