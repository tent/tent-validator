module TentValidator
  class ResponseExpectation

    class HeaderValidator < BaseValidator
      def validate(response)
        response_headers = response.env.response_headers
        _failed_assertions = failed_assertions(response_headers)
        super.merge(
          :failed_assertions => _failed_assertions.map(&:to_hash),
          :diff => diff(response_headers, _failed_assertions).map(&:to_hash),
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
