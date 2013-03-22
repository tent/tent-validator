require 'spec_helper'

describe TentValidator::Validator::Results do
  let(:validator) { stub(:name => "GET /foo") }
  let(:other_validator) { stub(:name => "with bar") }
  let(:results) {
    [
      {
        :response_headers => {
          :assertions => [],
          :failed_assertions => [],
          :diff => [],
          :valid => true
        }
      }
    ]
  }
  let(:instance) { described_class.new(validator, results) }
  let(:other_instance) { described_class.new(other_validator, results) }

  describe "#as_json" do
    let(:expected_output) {
      {
        "GET /foo" => {
          :results => results
        }
      }
    }
    it "returns results nested under validator name" do
      expect(instance.as_json).to eql(expected_output)
    end
  end

  describe "#merge!" do
    let(:expected_output) {
      {
        "GET /foo" => {
          :results => results,
          "with bar" => {
            :results => results
          }
        }
      }
    }

    it "merges given results as children and returns self" do
      expect(instance.merge!(other_instance)).to eql(instance)
      expect(instance.results).to eql(expected_output)
    end
  end
end

