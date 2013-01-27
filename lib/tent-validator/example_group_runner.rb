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
      example_group_res = example_group.run

      # Run all dependent example groups concurrently
      dependent_runners_res = example_group.dependent_example_groups.map { |g|
        runner = ExampleGroupRunner.new_link(g)
        @dependent_runners << runner
        runner.run
      }.flatten(1)

      res = [example_group_res].concat(dependent_runners_res)

      @dependent_runners.each(&:terminate)
      @dependent_runners = []

      res
    end
  end
end
