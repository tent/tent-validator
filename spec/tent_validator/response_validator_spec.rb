require 'spec_helper'

class TestValidator < TentValidator::ResponseValidator
  register :test

  def validate(response, options)
    if response.body == 'test'
      true
    else
      [false, "expected \"test\", got(#{response.body.inspect})"]
    end
  end
end

describe TentValidator::ResponseValidator do
  it "should register custom validators" do
    expect(described_class.validate(:test) { stub(:body => 'test') }).to be_passed
    expect(described_class.validate(:test) { stub(:body => nil) }).to_not be_passed
  end

  it "should raise exception when specified validator doesn't exist" do
    expect(lambda {
      described_class.validate(:unknown)
    }).to raise_error(described_class::ValidatorNotFoundError)
  end
end
