require 'spec_helper'

describe TentValidator::Validation do
  describe ".describe" do
    it "should return an ExampleGroup" do
      expect(described_class.describe).to be_an(TentValidator::ExampleGroup)
    end

    it "should take an optional description" do
      # assume the absense of an argument error == description accepted
      expect(described_class.describe("description")).to be_an(TentValidator::ExampleGroup)
    end
  end

  describe ".run" do
    it "should run all example groups" do
      called_examples = []
      example_group_1 = described_class.describe("example_1") { called_examples << self }
      example_group_2 = described_class.describe("example_2") { called_examples << self }
      described_class.run
      expect(called_examples.size).to eql(2)
      expect(called_examples).to include(example_group_1)
      expect(called_examples).to include(example_group_2)
    end

    it "should return validation results object" do
      expect(described_class.run).to be_a(TentValidator::Results)
    end
  end
end
