require 'spec_helper'

describe TentValidator::BeforeIdParamValidator do
  5.downto(1).each do |n|
    let(:"resource_#{n}") {
      {
        'id' => "public_id-#{n}"
      }
    }
  end

  let(:resources) { [resource_5, resource_4, resource_3, resource_2, resource_1] }
  let(:validator) { described_class.new(:resources => resources) }

  it "should register :before_id" do
    expect(validator.name).to eql(:before_id)
    expect(TentValidator::ParamValidator.find(:before_id)).to eql(described_class)
  end

  it "should set last given resource's id in before_id param" do
    expect(validator.client_params[:before_id]).to eql(resource_5['id'])
  end

  it "should validate given resources after the first are returned in given order" do
    expect(validator.response_expectation_options[:body_begins_with]).to eql([resource_4, resource_3, resource_2, resource_1])
    expect(validator.response_expectation_options[:body_excludes]).to eql([resource_5])
  end
end
