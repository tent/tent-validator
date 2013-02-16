require 'spec_helper'

describe "BeforeTimeParamValidator and SinceTimeParamValidator" do
  1.upto(5).each do |n|
    let(:"resource_#{n}") {
      {
        'received_at' => n * 1000000000
      }
    }
  end

  let(:resources) { [resource_5, resource_4, resource_3, resource_2, resource_1] }
  let(:before_time_validator) { TentValidator::BeforeTimeParamValidator.new(:resources => resources) }
  let(:since_time_validator) { TentValidator::SinceTimeParamValidator.new(:resources => resources) }
  let(:validator) { before_time_validator.merge(since_time_validator) }

  it "should set before_time and since_time client params" do
    expect(validator.client_params[:before_time]).to eql(resource_5['received_at'])
    expect(validator.client_params[:since_time]).to eql(resource_1['received_at'])
  end

  it "should set expectation for resources after before_time and before since_time" do
    expect(validator.response_expectation_options[:body_begins_with]).to eql([resource_4, resource_3, resource_2])
    expect(validator.response_expectation_options[:body_excludes]).to include(resource_5)
    expect(validator.response_expectation_options[:body_excludes]).to include(resource_1)
  end
end
