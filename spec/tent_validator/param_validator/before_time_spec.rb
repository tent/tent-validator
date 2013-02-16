require 'spec_helper'

describe TentValidator::BeforeTimeParamValidator do
  1.upto(5).each do |n|
    let(:"resource_#{n}") {
      {
        'received_at' => n * 1000000000
      }
    }
  end

  let(:resources) { [resource_5, resource_4, resource_3, resource_2, resource_1] }
  let(:validator) { described_class.new(:resources => resources) }

  it "should register :before_time" do
    expect(validator.name).to eql(:before_time)
    expect(TentValidator::ParamValidator.find(:before_time)).to eql(described_class)
  end

  it "should set last given resource's received_at in before_time param" do
    expect(validator.client_params[:before_time]).to eql(resource_5['received_at'])
  end

  it "should validate given resources after the first are returned in given order" do
    expect(validator.response_expectation_options[:body_begins_with]).to eql([resource_4, resource_3, resource_2, resource_1])
    expect(validator.response_expectation_options[:body_excludes]).to eql([resource_5])
  end
end
