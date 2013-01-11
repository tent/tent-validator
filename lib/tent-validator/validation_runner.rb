require 'celluloid'

module TentValidator
  class ValidationRunner
    include Celluloid

    attr_reader :validation

    def initialize(validation)
      @validation = validation
      @runners = []
    end

    def run(&block)
      # Run all independent example_groups concurrently
      # then wait for them all to finish
      results = independent_example_groups.map { |g|
        runner = ExampleGroupRunner.new_link(g)
        @runners << runner
        runner.future.run
      }.flatten(1).map { |future|
        res = future.value
        res.each { |r| block.call(r) } if block
        res
      }.flatten(1)

      @runners.each(&:terminate)
      @runners = []

      Results.new(results)
    end

    def independent_example_groups
      validation.example_groups.reject { |g| g.dependent? }
    end
  end
end
