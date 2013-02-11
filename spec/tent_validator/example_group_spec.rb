require 'spec_helper'

describe TentValidator::ExampleGroup do
  let(:example_group) { described_class.new }
  let(:user) { TentD::Model::User.generate }

  let(:env) { Hashie::Mash.new(:status => 200, :response_headers => {}, :body => '') }
  let(:response) { Faraday::Response.new(env) }

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
      client = example_group.clients(:app, :server => :local, :user => user.id)
      expect(client).to be_a(TentClient)
    end
  end

  describe "#expect_response" do
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

    it "should validate response size" do
      example_group.expect_response(:void, :list => true, :size => 2) { response }

      response.stubs(:body => [{ "foo" => "bar" }, { "bar" => "foo" }])
      res = example_group.run
      expect(res.passed?).to be_true

      response.stubs(:body => [{ "foo" => "bar" }])
      res = example_group.run
      expect(res.passed?).to be_false
    end

    it "should validate list properties absent" do
      example_group.expect_response(:void, :list => true, :body_excludes => [{:foo => 'bar'}]) { response }

      response.stubs(:body => [{ "baz" => "bar" }, { "bar" => "foo" }])
      res = example_group.run
      expect(res.passed?).to be_true

      response.stubs(:body => [{ "foo" => "bar" }, { "bar" => "foo" }])
      res = example_group.run
      expect(res.passed?).to be_false
    end

    it "should validate list properties present" do
      example_group.expect_response(:void, :list => true, :body_begins_with => [{:foo => 'bar'}, {:baz => "bar"}]) { response }

      response.stubs(:body => [{ "foo" => "bar" }, { "baz" => "bar" }])
      res = example_group.run
      expect(res.passed?).to be_true

      # wrong order
      response.stubs(:body => [{ "baz" => "bar" }, { "foo" => "bar" }])
      res = example_group.run
      expect(res.passed?).to be_false

      response.stubs(:body => [{ "baz" => "bar" }, { "bar" => "foo" }])
      res = example_group.run
      expect(res.passed?).to be_false
    end
  end

  describe "#validate_params" do
    it 'should use specified param validators' do
      validator = Class.new(TentValidator::ParamValidator)
      validator.class_eval do
        register :blip

        define_method :generate_client_params do
          {
            :magnification => 10
          }
        end

        define_method :generate_response_expectation_options do
          {
            :properties => {
              'foo' => 'bar'
            }
          }
        end
      end

      actual_client_params = nil
      example_group.validate_params(:blip).expect_response(:void, :properties => { 'blender' => 'carrots' }) { |params|
        actual_client_params = params
        response
      }

      response.stubs(:body => { 'foo' => 'bar', 'blender' => 'carrots' })
      res = example_group.run
      expect(res.passed?).to be_true

      response.stubs(:body => { 'blender' => 'carrots' })
      res = example_group.run
      expect(res.passed?).to be_false

      expect(actual_client_params).to eql({ :magnification => 10 })
    end

    it 'should use all specified params validators' do
      validator = Class.new(TentValidator::ParamValidator)
      validator.class_eval do
        register :blip

        define_method :generate_client_params do
          {
            :magnification => 10
          }
        end

        define_method :generate_response_expectation_options do
          {
            :properties => {
              'foo' => 'bar'
            }
          }
        end
      end

      other_validator = Class.new(TentValidator::ParamValidator)
      other_validator.class_eval do
        register :damok

        define_method :generate_client_params do
          {
            :ocean => true
          }
        end

        define_method :generate_response_expectation_options do
          {
            :properties => {
              'Damok' => 'on the ocean',
              'Jilad' => 'on the ocean'
            }
          }
        end
      end

      actual_client_params = nil
      example_group.validate_params(:blip, :damok).expect_response(:void, :properties => { 'blender' => 'carrots' }) { |params|
        actual_client_params = params
        response
      }

      response.stubs(:body => { 'Damok' => 'on the ocean', 'Jilad' => 'on the ocean', 'foo' => 'bar', 'blender' => 'carrots' })
      res = example_group.run
      expect(res.passed?).to be_true

      response.stubs(:body => { 'foo' => 'bar', 'blender' => 'carrots' })
      res = example_group.run
      expect(res.passed?).to be_false

      response.stubs(:body => { 'Damok' => 'on the ocean', 'Jilad' => 'on the ocean', 'blender' => 'carrots' })
      res = example_group.run
      expect(res.passed?).to be_false

      expect(actual_client_params).to eql({ :magnification => 10, :ocean => true })
    end
  end
end
