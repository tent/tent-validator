module TentValidator
  class Validation
    def self.describe(description="", &block)
      example_group = ExampleGroup.new(description, &block)
      @example_groups ||= []
      @example_groups << example_group
      example_group
    end

    def self.run
      Results.new(@example_groups.map(&:run))
    end
  end
end
