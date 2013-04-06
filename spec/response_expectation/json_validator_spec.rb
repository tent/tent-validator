require 'spec_helper'
require 'hashie'

require 'support/shared_examples/response_expectation_validator_validate_method'

describe TentValidator::ResponseExpectation::JsonValidator do
  let(:env) { Hashie::Mash.new(:status => 200, :response_headers => {}, :body => '') }
  let(:response) { Faraday::Response.new(env) }
  let(:options) { Hash.new }
  let(:block) { proc { response } }
  let(:validator) { stub(:everything) }
  let(:instance) { TentValidator::ResponseExpectation.new(validator, options, &block) }
  let(:expectation_key) { :response_body }

  let(:res) { instance.json_validators.first.validate(response) }

  describe "#validate" do
    let(:expected_properties) do
      {
        :water => {
          :fire => "air",
          :coords => {
            :lat => "-19.65",
            :lng => "86.86"
          }
        },
        :air => "water fire",
        :fire => /\Aair/,
        :altitude => 500_000,
        :snacks => [
          {
            :name => "Chunky Bar",
            :quantity => 12
          },
          {
            :name => "Celery Sticks",
            :quantity => 30
          },
          {
            :name => "Peanut Butter Cups",
            :quantity => 1024
          },
          {
            :name => "Date Squares",
            :quantity => 256,
            :ingredients => [["Dates", { :quantity => 4, :units => "cups" }], ["Almonds", { :quantity => 10, :units => "cups" }]]
          }
        ]
      }
    end

    before do
      instance.expect_properties(expected_properties)
    end

    let(:expected_assertions) do
      [
        { :op => "test", :path => "/water/fire", :value => "air" },
        { :op => "test", :path => "/water/coords/lat", :value => "-19.65" },
        { :op => "test", :path => "/water/coords/lng", :value => "86.86" },
        { :op => "test", :path => "/air", :value => "water fire" },
        { :op => "test", :path => "/fire", :value => "/^air/", :type => "regexp" },
        { :op => "test", :path => "/altitude", :value => 500_000 },
        { :op => "test", :path => "/snacks/0/name", :value => "Chunky Bar" },
        { :op => "test", :path => "/snacks/0/quantity", :value => 12 },
        { :op => "test", :path => "/snacks/1/name", :value => "Celery Sticks" },
        { :op => "test", :path => "/snacks/1/quantity", :value => 30 },
        { :op => "test", :path => "/snacks/2/name", :value => "Peanut Butter Cups" },
        { :op => "test", :path => "/snacks/2/quantity", :value => 1024 },
        { :op => "test", :path => "/snacks/3/name", :value => "Date Squares" },
        { :op => "test", :path => "/snacks/3/quantity", :value => 256 },
        { :op => "test", :path => "/snacks/3/ingredients/0/0", :value => "Dates" },
        { :op => "test", :path => "/snacks/3/ingredients/0/1/quantity", :value => 4 },
        { :op => "test", :path => "/snacks/3/ingredients/0/1/units", :value => "cups" },
        { :op => "test", :path => "/snacks/3/ingredients/1/0", :value => "Almonds" },
        { :op => "test", :path => "/snacks/3/ingredients/1/1/quantity", :value => 10 },
        { :op => "test", :path => "/snacks/3/ingredients/1/1/units", :value => "cups" },
      ]
    end

    context "when expectation fails" do
      it_behaves_like "a response expectation validator #validate method"

      before do
        env.body = {
          "water" => {
            "fire" => "very hot",
            "depth" => 2_000_000_000,
            "coords" => {
              "lat" => "-19.65",
              "type" => "latlng"
            }
          },
          "fire" => "air water fire",
          "altitude" => 500_000,
          "type" => "random_data",
          "snacks" => [
            {
              "name" => "Chunky Bar",
              "quantity" => 12
            },
            {
              "name" => "Celery Sticks",
              "quantity" => 30
            },
            {
              "name" => "Peanut Butter Cups",
              "quantity" => 1024
            },
            {
              "name" => "Date Squares",
              "quantity" => 256,
              "ingredients" => [["Dates", { "quantity" => 4, "units" => "cups" }], ["Almonds", { "quantity" => 10, "units" => "cups" }]]
            }
          ]
        }
      end

      let(:expected_failed_assertions) do
        [
          { :op => "test", :path => "/water/fire", :value => "air" },
          { :op => "test", :path => "/water/coords/lng", :value => "86.86" },
          { :op => "test", :path => "/air", :value => "water fire" }
        ]
      end

      let(:expected_diff) do
        [
          { :op => "replace", :path => "/water/fire", :value => "air", :current_value => "very hot" },
          { :op => "add", :path => "/water/coords/lng", :value => "86.86" },
          { :op => "add", :path => "/air", :value => "water fire" }
        ]
      end
    end

    context "when expectation passes" do
      it_behaves_like "a response expectation validator #validate method"

      before do
        env.body = {
          "water" => {
            "fire" => "air",
            "depth" => 2_000_000_000,
            "coords" => {
              "lat" => "-19.65",
              "lng" => "86.86",
              "type" => "latlng"
            }
          },
          "air" => "water fire",
          "fire" => "air water fire",
          "altitude" => 500_000,
          "type" => "random_data",
          "snacks" => [
            {
              "name" => "Chunky Bar",
              "quantity" => 12
            },
            {
              "name" => "Celery Sticks",
              "quantity" => 30
            },
            {
              "name" => "Peanut Butter Cups",
              "quantity" => 1024
            },
            {
              "name" => "Date Squares",
              "quantity" => 256,
              "ingredients" => [["Dates", { "quantity" => 4, "units" => "cups" }], ["Almonds", { "quantity" => 10, "units" => "cups" }]]
            }
          ]
        }
      end

      let(:expected_diff) { [] }
      let(:expected_failed_assertions) { [] }
    end
  end
end
