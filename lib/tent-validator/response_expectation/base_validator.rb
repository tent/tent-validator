module TentValidator
  class ResponseExpectation

    class BaseValidator
      def initialize(expected)
        @expected = expected
        initialize_assertions(expected)
      end

      def assertions
        @assertions ||= []
      end

      def validate(response)
        {
          :assertions => assertions.map(&:to_hash)
        }
      end

      private

      def assertion_valid?(assertion, actual)
        value = assertion.value
        case value
        when Regexp
          value.match(actual.to_s)
        when Numeric
          (Numeric === actual) && (value == actual)
        else
          value == actual
        end
      end
    end

  end
end
