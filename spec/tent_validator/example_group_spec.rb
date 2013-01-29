require 'spec_helper'

describe TentValidator::ExampleGroup do
  let(:example_group) { described_class.new }

  context "without block" do
    it "should have pending flag" do
      example_group = described_class.new
      expect(example_group).to be_pending
    end
  end

  describe "#run" do
    it "should yield to given block via instance_eval" do
      context = nil
      example_group = described_class.new { context = self}
      example_group.run
      expect(context).to eql(example_group)
    end

    it "should return validation results object" do
      example_group = described_class.new {}
      expect(example_group.run).to be_a(TentValidator::Results)
    end
  end

  describe "#set(key, value) / #get(key)" do
    it "should set/get key in temp key/val store" do
      example_group.set(:foo, "bar")
      expect(example_group.get(:foo)).to eql("bar")
    end
  end

  describe "#clients" do
    let(:remote_server) { "https://example.org/tent" }
    let(:remote_auth_details) do
      {
        :mac_key_id => 'mac-key-id',
        :mac_algorithm => 'hmac-sha-256',
        :mac_key => 'mac-key'
      }
    end
    before(:each) do
      TentValidator.remote_server = remote_server
      TentValidator.remote_auth_details = remote_auth_details
    end
 
    it "should return client for remote app authorization" do
      client = example_group.clients(:app, :server => :remote)
      expect(client).to be_a(TentClient)
      expect(client.server_urls).to eql(Array(remote_server))
      %w[ mac_key_id mac_algorithm mac_key ].each { |option|
        expect(client.instance_eval { @options[option.to_sym] }).to eql(remote_auth_details[option.to_sym])
      }
    end

    it "should return client for local app authorization" do
      client = example_group.clients(:app, :server => :local)
      expect(client).to be_a(TentClient)
      expect(client.faraday_adapter).to eql(TentValidator.local_adapter)
    end
  end

  describe "#expect_response" do
    let(:env) { Hashie::Mash.new(:status => 200, :response_headers => {}, :body => '') }
    let(:response) { Faraday::Response.new(env) }
    before do
      foobar_schema = {
        "title" => "Foobar",
        "type" => "object",
        "properties" => {
          "foo" => {
            "description" => "foos and bars and such",
            "type" => "string",
            "required" => true
          }
        }
      }

      TentSchemas.stubs(:[]).with(:foobar).returns(foobar_schema)
    end

    it "should validate response against given schema" do
      example_group.expect_response(:void, :schema => :foobar) { response }

      response.stubs(:body => {
        "foo" => "bar"
      })
      res = example_group.run
      expect(res.passed?).to be_true

      response.stubs(:body => {
        "baz" => 20
      })
      res = example_group.run
      expect(res.passed?).to be_false
    end

    it "should validate each item in list response against given schema" do
      example_group.expect_response(:void, :schema => :foobar, :list => true) { response }

      response.stubs(:body => [{
        "foo" => "bar"
      }])
      res = example_group.run
      expect(res.passed?).to be_true

      response.stubs(:body => [{
        "foo" => "bar"
      }, {
        "baz" => 20
      }])
      res = example_group.run
      expect(res.passed?).to be_false
    end

    it "should validate response properties present" do
      example_group.expect_response(:void, :properties_present => [:foo]) { response }

      response.stubs(:body => {
        "foo" => "bar"
      })
      res = example_group.run
      expect(res.passed?).to be_true

      response.stubs(:body => {
        "baz" => 20
      })
      res = example_group.run
      expect(res.passed?).to be_false
    end

    it "should validate response properties absent" do
      example_group.expect_response(:void, :properties_absent => [:baz]) { response }

      response.stubs(:body => {
        "foo" => "bar"
      })
      res = example_group.run
      expect(res.passed?).to be_true

      response.stubs(:body => {
        "baz" => 20
      })
      res = example_group.run
      expect(res.passed?).to be_false
    end
  end
end
