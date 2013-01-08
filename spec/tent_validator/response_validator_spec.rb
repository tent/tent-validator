require 'spec_helper'

class TestValidator < TentValidator::ResponseValidator
  register :test

  def validate(options)
    expect(:body => 'test')
    super
  end
end

describe TentValidator::ResponseValidator do
  let(:env) { Hashie::Mash.new(:status => 200, :response_headers => {}, :body => '') }
  let(:response) { Faraday::Response.new(env) }

  it "should register custom validators" do
    response.stubs(:body => 'test')
    expect(described_class.validate(:test) { response }).to be_passed

    response.stubs(:body => nil)
    expect(described_class.validate(:test) { response }).to_not be_passed
  end

  it "should raise exception when specified validator doesn't exist" do
    expect(lambda {
      described_class.validate(:unknown)
    }).to raise_error(described_class::ValidatorNotFoundError)
  end
end

describe TentValidator::ResponseValidator::Expectation do
  let(:env) { Hashie::Mash.new(:status => 200, :response_headers => {}, :body => '') }
  let(:response) { Faraday::Response.new(env) }

  context 'response body' do
    it 'should set expectation for exact match of response body' do
      expectation = described_class.new(
        :body => 'test'
      )

      response.stubs(:body => 'test')
      expect(
        expectation.validate(response)
      ).to be_true

      response.stubs(:body => 'unexpected')
      expect(
        expectation.validate(response)
      ).to be_false
    end

    it 'should set expectation for partial match of response body' do
      expectation = described_class.new(
        :body => /test/i
      )

      response.stubs(:body => 'Testing')
      expect(
        expectation.validate(response)
      ).to be_true

      response.stubs(:body => 'unexpected')
      expect(
        expectation.validate(response)
      ).to be_false
    end

    it 'should set expectation for deep partial match of response body' do
      expectation = described_class.new(
        :body => {
          :foo => {
            :bar => /baz/i
          }
        }
      )

      response.stubs(:body => Yajl::Encoder.encode({ 'foo' => { 'bar' => 'Bazzer', 'baz' => 'bar' } }))
      expect(
        expectation.validate(response)
      ).to be_true

      response.stubs(:body => Yajl::Encoder.encode({ 'foo' => { 'bar' => 'foobar' } }))
      expect(
        expectation.validate(response)
      ).to be_false
    end
  end

  context 'response headers' do
    it 'should set expectation that specified headers be included with exact values' do
      expectation = described_class.new(
        :headers => {
          :foo => '25',
          :bar => 'baz'
        }
      )

      response.stubs(:headers => {  'foo' => '25', 'bar' => 'baz' })
      expect(
        expectation.validate(response)
      ).to be_true

      response.stubs(:headers => {  'foo' => '00', 'bar' => 'baz' })
      expect(
        expectation.validate(response)
      ).to be_false
    end

    it 'should set expectation that specified headers be included with approximate values' do
      expectation = described_class.new(
        :headers => {
          :foo => /\A\d+[a-z]\Z/
        }
      )

      response.stubs(:headers => { 'foo' => '25x', 'bar' => 'baz' })
      expect(
        expectation.validate(response)
      ).to be_true

      response.stubs(:headers => { 'foo' => 'xxx', 'bar' => 'baz' })
      expect(
        expectation.validate(response)
      ).to be_false
    end
  end

  context 'response status' do
    it 'should set expectation for exact response status' do
      expectation = described_class.new(
        :status => 304
      )

      response.stubs(:status => 304)
      expect(
        expectation.validate(response)
      ).to be_true

      response.stubs(:status => 200)
      expect(
        expectation.validate(response)
      ).to be_false
    end

    it 'should set expectation that response status is in given range' do
      expectation = described_class.new(
        :status => 200...300
      )

      response.stubs(:status => 200)
      expect(
        expectation.validate(response)
      ).to be_true

      response.stubs(:status => 204)
      expect(
        expectation.validate(response)
      ).to be_true

      response.stubs(:status => 299)
      expect(
        expectation.validate(response)
      ).to be_true

      response.stubs(:status => 300)
      expect(
        expectation.validate(response)
      ).to be_false
    end

    it 'should default to expecting 2xx' do
      expectation = described_class.new({})

      response.stubs(:status => 200)
      expect(
        expectation.validate(response)
      ).to be_true

      response.stubs(:status => 204)
      expect(
        expectation.validate(response)
      ).to be_true

      response.stubs(:status => 299)
      expect(
        expectation.validate(response)
      ).to be_true

      response.stubs(:status => 300)
      expect(
        expectation.validate(response)
      ).to be_false
    end
  end
end
