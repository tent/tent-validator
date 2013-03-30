require 'spec_helper'
require 'hashie'

require 'support/shared_examples/response_expectation_validator_validate_method'

describe TentValidator::ResponseExpectation::StatusValidator do
  let(:env) { Hashie::Mash.new(:status => 200, :response_headers => {}, :body => '') }
  let(:response) { Faraday::Response.new(env) }
  let(:options) { Hash.new }
  let(:block) { proc { response } }
  let(:validator) { stub(:everything) }
  let(:instance) { TentValidator::ResponseExpectation.new(validator, options, &block) }
  let(:expectation_key) { :response_status }

  let(:res) { instance.status_validator.validate(response) }

  describe "#validate" do
    let(:options) do
      {
        :status => 304
      }
    end

    let(:expected_assertions) do
      [
        { :op => "test", :path => "", :value => 304 }
      ]
    end

    context "when expectation fails" do
      it_behaves_like "a response expectation validator #validate method"

      before do
        env.status = 400
      end

      let(:expected_diff) { [{ :op => "replace", :path => "", :value => 304 }] }
      let(:expected_failed_assertions) { [expected_assertions.first] }
    end

    context "when expectation passes" do
      it_behaves_like "a response expectation validator #validate method"

      before do
        env.status = 304
      end

      let(:expected_diff) { [] }
      let(:expected_failed_assertions) { [] }
    end
  end
end
