require 'spec_helper'

describe "BeforeIdParamValidator, SinceIdParamValidator, and LimitParamValidator" do
  6.downto(1).each do |n|
    let(:"resource_#{n}") {
      {
        'id' => "public_id-#{n}"
      }
    }
  end

  let(:resources) { [resource_6, resource_5, resource_4, resource_3, resource_2, resource_1] }
  let(:before_id_validator) { TentValidator::BeforeIdParamValidator.new(:resources => resources) }
  let(:since_id_validator) { TentValidator::SinceIdParamValidator.new(:resources => resources) }
  let(:limit_validator) { TentValidator::LimitParamValidator.new(:resources => resources) }
  let(:validator) { before_id_validator.merge(since_id_validator, limit_validator) }

  it "should set before_id, since_id, and limit client params" do
    expect(validator.client_params[:before_id]).to eql(resource_6['id'])
    expect(validator.client_params[:since_id]).to eql(resource_1['id'])
    expect(validator.client_params[:limit] >= 1).to be_true
    expect(validator.client_params[:limit] <= resources.size).to be_true
  end

  it "should set expectation for resources after before_id and before since_id" do
    expect(validator.response_expectation_options[:body_excludes]).to include(resource_6)
    expect(validator.response_expectation_options[:body_excludes]).to include(resource_1)
    expect(validator.response_expectation_options[:body_begins_with]).to eql([resource_2, resource_3, resource_4, resource_5].slice(0, validator.client_params[:limit]).reverse)
  end
end
