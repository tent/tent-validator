module TentValidator
  class ResponseExpectation

    class HeaderValidator < BaseValidator
      def self.named_expectations
        @named_expectations ||= {}
      end

      def self.register(name, expected)
        named_expectations[name] = expected
      end

      def validate(response)
        response_headers = response.env[:response_headers]
        _failed_assertions = failed_assertions(response_headers)
        super.merge(
          :key => :response_headers,
          :failed_assertions => _failed_assertions.map(&:to_hash),
          :diff => diff(response_headers, _failed_assertions).map(&:to_hash),
          :valid => _failed_assertions.empty?
        )
      end

      private

      NoSuchExpectationError = Class.new(StandardError)
      def initialize_assertions(expected)
        unless Hash === expected
          name = expected
          unless expected = self.class.named_expectations[name]
            raise NoSuchExpectationError.new("Expected #{name.inspect} to be registered with #{self.class.name}!")
          end
        end

        @assertions = expected.inject([]) do |memo, (header, value)|
          memo << Assertion.new("/#{header}", value)
        end
      end

      def failed_assertions(actual)
        assertions.select do |assertion|
          header = key_from_path(assertion.path)
          !assertion_valid?(assertion, actual[header])
        end
      end

      def diff(actual, _failed_assertions)
        _failed_assertions.map do |assertion|
          header = key_from_path(assertion.path)
          assertion = assertion.to_hash
          if actual.has_key?(header)
            assertion[:op] = "replace"
            assertion[:current_value] = actual[header]
          else
            assertion[:op] = "add"
          end
          assertion
        end
      end

      def key_from_path(path)
        path.slice(1, path.length) # remove prefixed "/"
      end
    end

  end
end
