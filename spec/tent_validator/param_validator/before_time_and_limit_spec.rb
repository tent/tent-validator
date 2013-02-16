require 'spec_helper'

describe "BeforeTimeParamValidator and LimitParamValidator" do
  1.upto(5).each do |n|
    let(:"resource_#{n}") {
      {
        'received_at' => 1 * 1000000000
      }
    }
  end

  let(:resources) { [resource_5, resource_4, resource_3, resource_2, resource_1] }
  let(:before_time_validator) { TentValidator::BeforeTimeParamValidator.new(:resources => resources) }
  let(:limit_validator) { TentValidator::LimitParamValidator.new(:resources => resources) }
  let(:validator) { before_time_validator.merge(limit_validator) }

  it "should set before_time and limit params" do
    expect(validator.client_params[:before_time]).to eql(resource_5['received_at'])
    10.times do
      expect(validator.client_params[:limit] >= 1).to be_true
      expect(validator.client_params[:limit] <= resources.size).to be_true
    end
  end

  it "should set expectation for limit amount of resources after before_time" do
    10.times do
      validator = before_time_validator.merge(limit_validator)
      expect(validator.response_expectation_options[:body_begins_with]).to eql([resource_4, resource_3, resource_2, resource_1].slice(0, validator.client_params[:limit]))
      expect(validator.response_expectation_options[:body_excludes]).to eql([resource_5])
    end
  end
end
