require 'spec_helper'

describe "BeforeTimeParamValidator and SinceIdParamValidator" do
  1.upto(5).each_with_index do |n, i|
    let(:"resource_#{n}") {
      {
        'id' => "public_id-#{i+1}",
        'received_at' => n * 1000000000
      }
    }
  end

  let(:resources) { [resource_5, resource_4, resource_3, resource_2, resource_1] }
  let(:before_time_validator) { TentValidator::BeforeTimeParamValidator.new(:resources => resources) }
  let(:since_id_validator) { TentValidator::SinceIdParamValidator.new(:resources => resources) }
  let(:validator) { before_time_validator.merge(since_id_validator) }

  it "should set before_time and since_id client params" do
    expect(validator.client_params[:before_time]).to eql(resource_5['received_at'])
    expect(validator.client_params[:since_id]).to eql(resource_1['id'])
  end

  it "should set expectation for resources after before_time and before since_id" do
    expect(validator.response_expectation_options[:body_begins_with]).to eql([resource_4, resource_3, resource_2])
    expect(validator.response_expectation_options[:body_excludes]).to include(resource_5)
    expect(validator.response_expectation_options[:body_excludes]).to include(resource_1)
  end
end
