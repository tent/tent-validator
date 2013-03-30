require 'tent-validator/mixins/deep_merge'

module TentValidator
  class Validator

    class Results
      include Mixins::DeepMerge

      attr_reader :name, :results
      def initialize(validator, expectations_results)
        @name = validator.name
        @results = {
          @name => {
            :results => expectations_results
          }
        }
      end

      def merge!(other)
        deep_merge!(results[name], other.results)
        self
      end

      def as_json(options = {})
        results
      end
    end

  end
end
