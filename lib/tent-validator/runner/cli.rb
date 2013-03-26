module TentValidator
  module Runner

    class CLI
      def self.run(options = {})
        instance = self.new(options)
        instance.run
      end

      def initialize(options = {})
      end

      def run
        puts "Running Protocol Validations..."
        results = Runner.run
        p results.as_json
      end

      def validator_complete(results, options = {})
      end
    end

  end
end
