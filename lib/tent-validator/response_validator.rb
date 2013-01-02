module TentValidator
  class ResponseValidator

    Error = Class.new(StandardError)
    ValidatorNotFoundError = Class.new(Error)

    class Result
      attr_reader :response

      def initialize(params = {})
        @response = params[:response]
        @result = params[:result]
      end

      def passed?
        @result == true
      end

      # TODO: finish filling in data
      def as_json(options = {})
        {
          :request_headers => response.env[:request_headers],
          :request_body => nil,
          :request_path => nil,
          :request_params => nil,
          :request_server => nil,

          :response_headers => response.headers,
          :response_body => response.body,
          :response_status => response.status,

          :expected_response_headers => nil,
          :expected_response_body => nil,
          :expected_response_status => nil,

          :passed => passed?,
        }
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
      Result.new(
        :response => response,
        :result => validator.new.validate(response, options),
        :context => block.binding.eval("self")
      )
    end
  end
end
