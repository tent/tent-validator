require 'spec_helper'
require 'hashie'

require 'support/shared_examples/response_expectation_validator_validate_method'

describe TentValidator::ResponseExpectation::SchemaValidator do
  let(:env) { Hashie::Mash.new(:status => 200, :response_headers => {}, :body => '') }
  let(:response) { Faraday::Response.new(env) }
  let(:expectation_key) { :response_body }
  let(:instance) { described_class.new(:water) }
  let(:res) { instance.validate(response) }

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
          "description" => "list of river uris",
          "type" => "array",
          "items" => {
            "type" => "string",
            "format" => "uri"
          }
        },
      }
    }
  end

  let(:lake_schema) do
    {
      "title" => "Lake Schema",
      "type" => "object",
      "properties" => {
        "facts" => {
          "description" => "Random facts about the lake",
          "type" => "object",
          "required" => true,
          "properties" => {
            "fresh water" => {
              "description" => "Is it a fresh water lake?",
              "type" => "boolean",
              "required" => true
            },
            "sand" => {
              "description" => "Does the lake have a sandy bottom?",
              "type" => "boolean",
              "required" => true
            },
            "boats" => {
              "description" => "Are there boats on this lake?",
              "type" => "boolean"
            }
          }
        }
      }
    }
  end

  describe "#validate" do
    before do
      TentValidator::Schemas[:water] = water_schema
      TentValidator::Schemas[:lake] = lake_schema
    end

    context "with root pointer" do
      let(:instance) { described_class.new(:lake, "/content/lake") }

      let(:expected_assertions) do
        [
          { :op => "test", :path => "/content/lake/facts", :type => "object" },
          { :op => "test", :path => "/content/lake/facts/fresh water", :type => "boolean" },
          { :op => "test", :path => "/content/lake/facts/sand", :type => "boolean" },
        ]
      end

      context "when expectation passes" do
        let(:expected_failed_assertions) { [] }
        let(:expected_diff) { [] }

        context "without optional properties" do
          before do
            env.body = {
              "content" => {
                "lake" => {
                  "facts" => {
                    "fresh water" => true,
                    "sand" => true
                  }
                }
              }
            }
          end

          it_behaves_like "a response expectation validator #validate method"
        end

        context "with optional properties" do
          before do
            env.body = {
              "content" => {
                "lake" => {
                  "facts" => {
                    "fresh water" => true,
                    "sand" => true,
                    "boats" => false
                  }
                }
              }
            }
          end

          it_behaves_like "a response expectation validator #validate method"
        end
      end

      context "when expectation fails" do
        context "when missing required properties" do
          before do
            env.body = {
              "content" => {
                "lake" => {
                  "facts" => {
                    "sand" => true,
                    "boats" => false
                  }
                }
              }
            }
          end

          let(:expected_failed_assertions) do
            [
              { :op => "test", :path => "/content/lake/facts/fresh water", :type => "boolean" }
            ]
          end

          let(:expected_diff) do
            [
              { :op => "add", :path => "/content/lake/facts/fresh water", :value => false, :type => "boolean", :message => "expected type boolean, got null" }
            ]
          end

          it_behaves_like "a response expectation validator #validate method"
        end

        context "when extra properties present" do
          before do
            env.body = {
              "content" => {
                "lake" => {
                  "facts" => {
                    "fresh water" => true,
                    "sand" => true,
                    "boats" => false,
                    "air planes" => "lots and lots of them!"
                  }
                }
              }
            }
          end

          let(:expected_failed_assertions) do
            []
          end

          let(:expected_diff) do
            [
              { :op => "remove", :path => "/content/lake/facts/air planes" }
            ]
          end

          it_behaves_like "a response expectation validator #validate method"
        end

        context "when wrong type for property" do
          before do
            env.body = {
              "content" => {
                "lake" => {
                  "facts" => {
                    "fresh water" => "yes!",
                    "sand" => true,
                    "boats" => false,
                  }
                }
              }
            }
          end

          let(:expected_failed_assertions) do
            [
              { :op => "test", :path => "/content/lake/facts/fresh water", :type => "boolean" }
            ]
          end

          let(:expected_diff) do
            [
              { :op => "replace", :path => "/content/lake/facts/fresh water", :value => true, :current_value => "yes!", :type => "boolean", :message => "expected type boolean, got string" },
            ]
          end

          it_behaves_like "a response expectation validator #validate method"
        end
      end
    end

    context "when root pointer omitted" do
      let(:instance) { described_class.new(:water) }

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
              "rivers" => ["http://baron.example.org", "custom://user:pass@grape.super-baron.example.com:3042/some@path:foo&bar+=$,/?foo=bar"]
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
              },
              "rivers" => ["http://foo.example.com", 123, "https://bar.example.org", { "this" => "should be a string" }]
            }
          end

          let(:expected_failed_assertions) do
            [
              { :op => "test", :path => "/water/depth", :type => "number" }
            ]
          end

          let(:expected_diff) do
            [
              { :op => "replace", :path => "/water/depth", :value => 400_000_000.0, :current_value => "400_000_000", :type => "number", :message => "expected type number, got string" },
              { :op => "replace", :path => "/water/coords/lat", :value => "-19.65", :current_value => -19.65, :type => "string", :message => "expected type string, got number" },
              { :op => "replace", :path => "/rivers/1", :value => "123", :current_value => 123, :type => "string", :message => "expected type string, got integer" },
              { :op => "replace", :path => "/rivers/3", :value => %({"this"=>"should be a string"}), :current_value => { "this" => "should be a string" }, :type => "string", :message => "expected type string, got object" },
            ]
          end

          it_behaves_like "a response expectation validator #validate method"
        end
      end
    end
  end
end
