require 'spec_helper'
require 'hashie'

require 'support/shared_examples/response_expectation_validator_validate_method'

describe TentValidator::ResponseExpectation::HeaderValidator do
  let(:env) { Hashie::Mash.new(:status => 200, :response_headers => {}, :body => '') }
  let(:response) { Faraday::Response.new(env) }
  let(:block) { proc { response } }
  let(:validator) { stub(:everything) }
  let(:instance) { described_class.new(expected) }
  let(:expectation_key) { :response_headers }

  let(:res) { instance.validate(response) }

  describe "#validate" do
    let(:expected) do
      {
        "Count" => /\A\d+\Z/,
        "Say Hello" => "Hello Tent!"
      }
    end

    let(:expected_assertions) {
      [
        { :op => "test", :path => "/Count", :value => "/^\\d+$/", :type => "regexp" },
        { :op => "test", :path => "/Say Hello", :value => "Hello Tent!" }
      ]
    }

    context "when expectation fails" do
      context "when expectation is a Regexp" do
        it_behaves_like "a response expectation validator #validate method"

        before do
          env.response_headers = {
            "Count" => "NaN",
            "Say Hello" => "Hello Tent!"
          }
        end

        let(:expected_diff) { [{ :op => "replace", :path => "/Count", :value => "/^\\d+$/", :type => "regexp" }] }
        let(:expected_failed_assertions) { [expected_assertions.first] }
      end

      context "when expectation is a String" do
        it_behaves_like "a response expectation validator #validate method"

        before do
          env.response_headers = {
            "Count" => "185",
            "Say Hello" => "No, I won't do it!"
          }
        end

        let(:expected_diff) { [{ :op => "replace", :path => "/Say Hello", :value => "Hello Tent!" }] }
        let(:expected_failed_assertions) { [expected_assertions.last] }
      end

      context "when header missing" do
        it_behaves_like "a response expectation validator #validate method"

        before do
          env.response_headers = {
            "Count" => "185",
          }
        end

        let(:expected_diff) { [{ :op => "add", :path => "/Say Hello", :value => "Hello Tent!" }] }
        let(:expected_failed_assertions) { [expected_assertions.last] }
      end
    end

    context "when expectation passes" do
      it_behaves_like "a response expectation validator #validate method"

      before do
        env.response_headers = {
          "Count" => "198",
          "Say Hello" => "Hello Tent!"
        }
      end

      let(:expected_diff) { [] }
      let(:expected_failed_assertions) { [] }
    end
  end
end
