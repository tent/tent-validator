require 'spec_helper'

describe "BeforeTimeParamValidator, SinceTimeParamValidator, and LimitParamValidator" do
  1.upto(6).each do |n|
    let(:"resource_#{n}") {
      {
        'received_at' => n * 1000000000
      }
    }
  end

  let(:resources) { [resource_6, resource_5, resource_4, resource_3, resource_2, resource_1] }
  let(:before_time_validator) { TentValidator::BeforeTimeParamValidator.new(:resources => resources) }
  let(:since_time_validator) { TentValidator::SinceTimeParamValidator.new(:resources => resources) }
  let(:limit_validator) { TentValidator::LimitParamValidator.new(:resources => resources) }
  let(:validator) { before_time_validator.merge(since_time_validator, limit_validator) }

  it "should set before_time, since_time, and limit client params" do
    expect(validator.client_params[:before_time]).to eql(resource_6['received_at'])
    expect(validator.client_params[:since_time]).to eql(resource_1['received_at'])
    expect(validator.client_params[:limit] >= 1).to be_true
    expect(validator.client_params[:limit] <= resources.size).to be_true
  end

  it "should set expectation for resources after before_time and before since_time" do
    expect(validator.response_expectation_options[:body_excludes]).to include(resource_6)
    expect(validator.response_expectation_options[:body_excludes]).to include(resource_1)
    expect(validator.response_expectation_options[:body_begins_with]).to eql([resource_2, resource_3, resource_4, resource_5].slice(0, validator.client_params[:limit]).reverse)
  end
end
