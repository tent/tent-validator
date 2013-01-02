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
    expect(described_class.validate(:test) { stub(:body => 'test') }).to be_true
    res = described_class.validate(:test) { stub(:body => nil) }
    expect(res.size).to eql(2)
    expect(res.first).to be_false
    expect(res.last).to be_a(String)
  end

  it "should raise exception when specified validator doesn't exist" do
    expect(lambda {
      described_class.validate(:unknown)
    }).to raise_error(described_class::ValidatorNotFoundError)
  end
end
