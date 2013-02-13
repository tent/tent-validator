require 'spec_helper'

describe TentValidator::LimitParamValidator do
  it "should register as :limit" do
    validator = described_class.new({})
    expect(validator.name).to eql(:limit)
    expect(TentValidator::ParamValidator.find(:limit)).to eql(described_class)
  end

  it "should pass limit param to client and set equal size response expectation" do
    resources = 15.times.to_a
    20.times do
      validator = described_class.new(:resources => resources)
      expect(validator.client_params[:limit]).to_not be_nil
      expect(validator.client_params[:limit] > 0).to be_true
      expect(validator.client_params[:limit] < 15).to be_true
      expect(validator.client_params[:limit]).to eql(validator.response_expectation_options[:size])
    end
  end
end
