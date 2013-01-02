module TentValidator
  class Validation
    def self.describe(description=nil, &block)
      example_group = ExampleGroup.new(description, &block)
      @example_groups ||= []
      @example_groups << example_group
      example_group
    end

    def self.run
      @example_groups.each(&:run)
      CombinedResults.new
    end
  end
end
