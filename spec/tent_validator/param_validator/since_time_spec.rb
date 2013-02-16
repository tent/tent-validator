require 'spec_helper'

describe TentValidator::SinceTimeParamValidator do
  1.upto(5).each do |n|
    let(:"resource_#{n}") {
      {
        'received_at' => Time.now.to_i - (n * 86400)
      }
    }
  end

  let(:resources) { [resource_5, resource_4, resource_3, resource_2, resource_1] }
  let(:validator) { described_class.new(:resources => resources) }

  it "should register :since_time" do
    expect(validator.name).to eql(:since_time)
    expect(TentValidator::ParamValidator.find(:since_time)).to eql(described_class)
  end

  it "should set first given resource's id in since_time param" do
    expect(validator.client_params[:since_time]).to eql(resource_1['received_at'])
  end

  it "should validate given resources after the last are returned in given order" do
    expect(validator.response_expectation_options[:body_begins_with]).to eql([resource_5, resource_4, resource_3, resource_2])
    expect(validator.response_expectation_options[:body_excludes]).to eql([resource_1])
  end
end
