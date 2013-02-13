require 'spec_helper'

describe "SinceIdParamValidator and LimitParamValidator" do
  5.downto(1).each do |n|
    let(:"resource_#{n}") {
      {
        'id' => "public_id-#{n}"
      }
    }
  end

  let(:resources) { [resource_5, resource_4, resource_3, resource_2, resource_1] }
  let(:since_id_validator) { TentValidator::SinceIdParamValidator.new(:resources => resources) }
  let(:limit_validator) { TentValidator::LimitParamValidator.new(:resources => resources) }
  let(:validator) { since_id_validator.merge(limit_validator) }

  it "should set since_id and limit params" do
    expect(validator.client_params[:since_id]).to eql(resource_1['id'])
    10.times do
      expect(validator.client_params[:limit] >= 1).to be_true
      expect(validator.client_params[:limit] <= resources.size).to be_true
    end
  end

  it "should set expectation for limit amount of resources before since_id" do
    20.times do
      validator = since_id_validator.merge(limit_validator)
      expect(validator.response_expectation_options[:body_begins_with]).to eql([resource_2, resource_3, resource_4, resource_5].slice(0, validator.client_params[:limit]).reverse)
      expect(validator.response_expectation_options[:body_excludes]).to eql([resource_1])
    end
  end
end
