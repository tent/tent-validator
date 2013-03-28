require 'spec_helper'
require 'hashie'

require 'support/shared_examples/response_expectation_validator_validate_method'

describe TentValidator::ResponseExpectation::SchemaValidator do
  let(:env) { Hashie::Mash.new(:status => 200, :response_headers => {}, :body => '') }
  let(:response) { Faraday::Response.new(env) }
  let(:options) { Hash.new }
  let(:block) { proc { response } }
  let(:validator) { stub(:everything) }
  let(:instance) { TentValidator::ResponseExpectation.new(validator, options, &block) }

  let(:res) { instance.schema_validator.validate(response) }

  let(:water_schema) do
    {
      "title" => "Test Object",
      "type" => "object",
      "properties" => {
        "water" => {
          "description" => "a wet substance",
          "type" => "object",
          "required" => true,

          "properties" => {
            "depth" => {
              "description" => "depth of water in meters",
              "type" => "number",
              "required" => true
            },
            "coords" => {
              "description" => "location the middle of water mass",
              "type" => "object",
              "required" => false,

              "properties" => {
                "lat" => {
                  "description" => "latitude",
                  "type" => "string",
                  "required" => true
                },
                "lng" => {
                  "description" => "longitude",
                  "type" => "string",
                  "required" => true
                }
              }
            },
            "attributes" => {
              "description" => "key/value pairs describing the water",
              "type" => "object",
              "required" => true
            },
            "lake" => {
              "description" => "is it a lake?",
              "type" => "boolean"
            },
            "volume" => {
              "description" => "volume of water mass",
              "type" => "integer"
            }
          }
        },
        "rivers" => {
          "description" => "rivers of water",
          "type" => "array"
        },
      }
    }
  end

  describe "#validate" do
    let(:options) do
      { :schema => :water }
    end

    before do
      TentValidator::Schemas[:water] = water_schema
    end

    let(:expected_assertions) do
      [
        { :op => "test", :path => "/water", :type => "object" },
        { :op => "test", :path => "/water/depth", :type => "number" },
        { :op => "test", :path => "/water/attributes", :type => "object"}
      ]
    end

    context "when expectation passes" do
      let(:expected_failed_assertions) { [] }
      let(:expected_diff) { [] }

      context "without optional properties" do
        before do
          env.body = {
            "water" => {
              "depth" => 2_000_000_000,
              "attributes" => {
                "foo" => "bar"
              }
            }
          }
        end

        it_behaves_like "a response expectation validator #validate method"
      end

      context "with optional properties" do
        before do
          env.body = {
            "water" => {
              "depth" => 2_000_000_000,
              "attributes" => {
                "foo" => "bar"
              },
              "coords" => {
                "lat" => "-19.65",
                "lng" => "86.86",
              },
              "lake" => true,
              "volume" => 900_000_000_000_000_000
            },
            "rivers" => ["baron", "grape"]
          }
        end

        it_behaves_like "a response expectation validator #validate method"
      end
    end

    context "when expectation failes" do
      context "when missing required properties" do
        before do
          env.body = {
            "water" => {
              "attributes" => {
                "foo" => "bar"
              },
              "coords" => {
                "lat" => "-19.65",
                "lng" => "86.86",
              }
            }
          }
        end

        let(:expected_failed_assertions) do
          [
            { :op => "test", :path => "/water/depth", :type => "number" }
          ]
        end

        let(:expected_diff) do
          [
            { :op => "add", :path => "/water/depth", :value => 0.0, :type => "number", :message => "expected type number, got null" }
          ]
        end

        it_behaves_like "a response expectation validator #validate method"
      end

      context "when extra properties present" do
        before do
          env.body = {
            "water" => {
              "depth" => 400_000_000,
              "attributes" => {
                "foo" => "bar"
              },
              "coords" => {
                "lat" => "-19.65",
                "lng" => "86.86",
                "foo" => "bar"
              }
            },
            "extra" => {
              "something" => "else"
            },
            "fire" => "air"
          }
        end

        let(:expected_failed_assertions) do
          []
        end

        let(:expected_diff) do
          [
            { :op => "remove", :path => "/water/coords/foo" },
            { :op => "remove", :path => "/extra" },
            { :op => "remove", :path => "/fire" }
          ]
        end

        it_behaves_like "a response expectation validator #validate method"
      end

      context "when wrong type for property" do
        before do
          env.body = {
            "water" => {
              "depth" => "400_000_000",
              "attributes" => {
                "foo" => "bar"
              },
              "coords" => {
                "lat" => -19.65,
                "lng" => "86.86",
              }
            }
          }
        end

        let(:expected_failed_assertions) do
          [
            { :op => "test", :path => "/water/depth", :type => "number" }
          ]
        end

        let(:expected_diff) do
          [
            { :op => "replace", :path => "/water/depth", :value => 400_000_000.0, :type => "number", :message => "expected type number, got string" },
            { :op => "replace", :path => "/water/coords/lat", :value => "-19.65", :type => "string", :message => "expected type string, got number" }
          ]
        end

        it_behaves_like "a response expectation validator #validate method"
      end
    end
  end
end
