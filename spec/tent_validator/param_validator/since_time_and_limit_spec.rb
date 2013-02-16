require 'spec_helper'

describe "SinceTimeParamValidator and LimitParamValidator" do
  1.upto(5).each do |n|
    let(:"resource_#{n}") {
      {
        'received_at' => 1 * 1000000000
      }
    }
  end

  let(:resources) { [resource_5, resource_4, resource_3, resource_2, resource_1] }
  let(:since_time_validator) { TentValidator::SinceTimeParamValidator.new(:resources => resources) }
  let(:limit_validator) { TentValidator::LimitParamValidator.new(:resources => resources) }
  let(:validator) { since_time_validator.merge(limit_validator) }

  it "should set since_time and limit params" do
    expect(validator.client_params[:since_time]).to eql(resource_1['received_at'])
    10.times do
      expect(validator.client_params[:limit] >= 1).to be_true
      expect(validator.client_params[:limit] <= resources.size).to be_true
    end
  end

  it "should set expectation for limit amount of resources before since_time" do
    20.times do
      validator = since_time_validator.merge(limit_validator)
      expect(validator.response_expectation_options[:body_begins_with]).to eql([resource_2, resource_3, resource_4, resource_5].slice(0, validator.client_params[:limit]).reverse)
      expect(validator.response_expectation_options[:body_excludes]).to eql([resource_1])
    end
  end
end
