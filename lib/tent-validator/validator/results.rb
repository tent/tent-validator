module TentValidator
  class Validator

    class Results
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
        results[name].merge!(other.results)
        self
      end

      def as_json(options = {})
        results
      end
    end

  end
end
