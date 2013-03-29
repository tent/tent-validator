require 'json-patch/hash_pointer'

module TentValidator
  class ResponseExpectation

    class JsonValidator < BaseValidator
      def validate(response)
        response_body = response.body.to_hash
        _failed_assertions = failed_assertions(response_body)
        super.merge(
          :key => 'response_body',
          :failed_assertions => _failed_assertions.map(&:to_hash),
          :diff => diff(response_body, _failed_assertions),
          :valid => _failed_assertions.empty?
        )
      end

      private

      def initialize_assertions(expected, parent_path = "")
        expected.each_pair do |key, val|
          path = [parent_path, key].join("/")
          case val
          when Hash
            initialize_assertions(val, path)
          else
            assertions << Assertion.new(path, val)
          end
        end
      end

      def failed_assertions(actual)
        assertions.select do |assertion|
          pointer = JsonPatch::HashPointer.new(actual, assertion.path)
          !pointer.exists? || !assertion_valid?(assertion, pointer.value)
        end
      end

      def diff(actual, _failed_assertions)
        _failed_assertions.map do |assertion|
          pointer = JsonPatch::HashPointer.new(actual, assertion.path)
          assertion = assertion.to_hash
          if pointer.exists?
            assertion[:op] = "replace"
          else
            assertion[:op] = "add"
          end
          assertion
        end
      end
    end

  end
end
