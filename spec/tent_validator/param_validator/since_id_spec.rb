require 'spec_helper'

describe TentValidator::SinceIdParamValidator do
  5.downto(1).each do |n|
    let(:"resource_#{n}") {
      {
        'id' => "public_id-#{n}"
      }
    }
  end

  let(:resources) { [resource_5, resource_4, resource_3, resource_2, resource_1] }
  let(:validator) { described_class.new(:resources => resources) }

  it "should register :since_id" do
    expect(validator.name).to eql(:since_id)
    expect(TentValidator::ParamValidator.find(:since_id)).to eql(described_class)
  end

  it "should set first given resource's id in since_id param" do
    expect(validator.client_params[:since_id]).to eql(resource_1['id'])
  end

  it "should validate given resources after the last are returned in given order" do
    expect(validator.response_expectation_options[:body_begins_with]).to eql([resource_5, resource_4, resource_3, resource_2])
    expect(validator.response_expectation_options[:body_excludes]).to eql([resource_1])
  end
end
