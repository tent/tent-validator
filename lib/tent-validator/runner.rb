require 'api-validator'
require 'awesome_print'

module TentValidator
  module Runner

    class Results
      include ApiValidator::Mixins::DeepMerge

      attr_reader :results
      def initialize
        @results = {}
      end

      def merge!(validator_results)
        deep_merge!(results, validator_results.results)
      end

      def as_json(options = {})
        results
      end
    end

    require 'tent-validator/runner/cli'

    def self.run(&block)
      TentValidator.run_local_server!

      paths = Dir[File.expand_path(File.join(File.dirname(__FILE__), 'validators', '**', '*_validator.rb'))]
      paths.each { |path| require path }

      results = Results.new

      TentValidator.validators.each do |validator|
        begin
          results.merge!(validator.run)
          block.call(results) if block
        rescue SetupFailure => e
          if e.results
            _setup_failure_results = ApiValidator::ResponseExpectation::Results.new(e.response, [e.results])
            results.merge!(ApiValidator::Spec::Results.new(validator, [_setup_failure_results]))
          else
            puts %(<#{validator.name} SetupFailure "#{e.message}">:)

            if e.response
              print "\tRESPONSE:\n\t"
              print "status: #{e.response.status}\n\t"
              begin
                print Yajl::Encoder.encode(e.response.body)
              rescue
                print e.response.body
              end
              print "\n\n"
            end

            puts "\t" + e.backtrace.join("\n\t")
          end
        end
      end

      results
    end

  end
end
