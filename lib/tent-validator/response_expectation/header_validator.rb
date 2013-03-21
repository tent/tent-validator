module TentValidator
  class ResponseExpectation

    class HeaderValidator < BaseValidator
      def validate(response)
        response_headers = response.env.response_headers
        _failed_assertions = failed_assertions(response_headers)
        super.merge(
          :failed_assertions => _failed_assertions.map(&:to_hash),
          :diff => diff(_failed_assertions).map(&:to_hash),
          :valid => _failed_assertions.empty?
        )
      end

      private

      def initialize_assertions(expected)
        @assertions = expected.inject([]) do |memo, (header, value)|
          memo << Assertion.new("/#{header}", value)
        end
      end

      def failed_assertions(actual)
        assertions.select do |assertion|
          header = assertion.path.slice(1, assertion.path.length) # remove prefixed "/"
          !assertion_valid?(assertion, actual[header])
        end
      end

      def diff(_failed_assertions)
        _failed_assertions.map do |assertion|
          assertion = assertion.to_hash
          assertion[:op] = "replace"
          assertion
        end
      end
    end

  end
end
