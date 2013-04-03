module TentValidator
  class ResponseExpectation

    class StatusValidator < BaseValidator
      def validate(response)
        response_status = response.status
        _failed_assertions = failed_assertions(response_status)
        super.merge(
          :key => :response_status,
          :failed_assertions => _failed_assertions.map(&:to_hash),
          :diff => diff(response_status, _failed_assertions),
          :valid => _failed_assertions.empty?
        )
      end

      private

      def initialize_assertions(expected)
        @assertions = [ Assertion.new("", expected) ]
      end

      def failed_assertions(actual)
        assertions.select do |assertion|
          !assertion_valid?(assertion, actual)
        end
      end

      def diff(actual, _failed_assertions)
        _failed_assertions.map do |assertion|
          assertion = assertion.to_hash
          assertion[:op] = "replace"
          assertion[:current_value] = actual
          assertion
        end
      end
    end

  end
end
