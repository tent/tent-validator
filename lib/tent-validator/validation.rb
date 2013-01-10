module TentValidator
  class Validation
    class << self
      attr_reader :example_groups
    end

    def self.describe(description="", options={}, &block)
      example_group = ExampleGroup.new(description, options, &block)
      @example_groups ||= []
      @example_groups << example_group
      example_group
    end

    # Run all example_groups concurrently
    def self.run
      runner = ValidationRunner.new(self)
      res = runner.run
      runner.terminate
      res
    end
  end
end
