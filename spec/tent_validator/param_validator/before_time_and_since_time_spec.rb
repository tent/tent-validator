require 'spec_helper'

describe "BeforeIdParamValidator and SinceIdParamValidator" do
  5.downto(1).each do |n|
    let(:"resource_#{n}") {
      {
        'id' => "public_id-#{n}"
      }
    }
  end

  let(:resources) { [resource_5, resource_4, resource_3, resource_2, resource_1] }
  let(:before_id_validator) { TentValidator::BeforeIdParamValidator.new(:resources => resources) }
  let(:since_id_validator) { TentValidator::SinceIdParamValidator.new(:resources => resources) }
  let(:validator) { before_id_validator.merge(since_id_validator) }

  it "should set before_id and since_id client params" do
    expect(validator.client_params[:before_id]).to eql(resource_5['id'])
    expect(validator.client_params[:since_id]).to eql(resource_1['id'])
  end

  it "should set expectation for resources after before_id and before since_id" do
    expect(validator.response_expectation_options[:body_begins_with]).to eql([resource_4, resource_3, resource_2])
    expect(validator.response_expectation_options[:body_excludes]).to include(resource_5)
    expect(validator.response_expectation_options[:body_excludes]).to include(resource_1)
  end
end
