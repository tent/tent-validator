require 'celluloid'

module TentValidator
  class ExampleGroupRunner
    include Celluloid

    attr_reader :example_group

    def initialize(example_group)
      @example_group = example_group
      @dependent_runners = []
    end

    def run
      res = [
        example_group.run,

        # Run all dependent example groups concurrently
        example_group.dependent_example_groups.map { |g|
          runner = ExampleGroupRunner.new_link(g)
          @dependent_runners << runner
          runner.future.run
        }.map(&:value)
      ].flatten

      @dependent_runners.each(&:terminate)
      @dependent_runners = []

      res
    end
  end
end
