require 'spec_helper'
require 'hashie'

describe TentValidator::ResponseValidator do
  let(:env) { Hashie::Mash.new(:status => 200, :response_headers => {}, :body => '') }
  let(:response) { Faraday::Response.new(env) }
  let(:block) { lambda {} }

  it "should register custom validators" do
    VoidResponseValidator.any_instance.expects(:validate) # spec/support/void_response_validator.rb
    described_class.validate(:void) { response }
  end

  it "should raise exception when specified validator doesn't exist" do
    expect(lambda {
      described_class.validate(:unknown)
    }).to raise_error(described_class::ValidatorNotFoundError)
  end

  context "validate headers" do
    it "exact match when passing" do
      validator_class = Class.new(described_class)
      validator_class.class_eval do
        validate_headers do
          expect_header('Access-Control-Allow-Origin', '*')
        end
      end

      env.response_headers['Access-Control-Allow-Origin'] = '*'

      expect(
        validator_class.new(response, block).validate({})
      ).to be_passed
    end

    it "exact match when failing" do
      validator_class = Class.new(described_class)
      validator_class.class_eval do
        validate_headers do
          expect_header('Access-Control-Allow-Origin', '*')
        end
      end

      env.response_headers['Access-Control-Allow-Origin'] = 'foo'

      expect(
        validator_class.new(response, block).validate({})
      ).to_not be_passed
    end

    it "match list inclusion when passing" do
      validator_class = Class.new(described_class)
      validator_class.class_eval do
        validate_headers do
          expect_header('Access-Control-Allow-Methods', %w( GET POST HEAD ), :split => /[^a-z]+/i)
        end
      end

      env.response_headers['Access-Control-Allow-Methods'] = 'GET, OPTIONS, POST, HEAD, DELETE'

      expect(
        validator_class.new(response, block).validate({})
      ).to be_passed
    end

    it "match list inclusion when failing" do
      validator_class = Class.new(described_class)
      validator_class.class_eval do
        validate_headers do
          expect_header('Access-Control-Allow-Methods', %w( GET POST HEAD ), :split => /[^a-z]+/i)
        end
      end

      env.response_headers['Access-Control-Allow-Methods'] = 'OPTIONS, POST, HEAD, DELETE'

      expect(
        validator_class.new(response, block).validate({})
      ).to_not be_passed
    end

    it "match via regex when passing" do
      validator_class = Class.new(described_class)
      validator_class.class_eval do
        validate_headers do
          expect_header('Access-Control-Expose-Headers', /\bCount\b/)
          expect_header('Access-Control-Expose-Headers', /\bLink\b/)
        end
      end

      env.response_headers['Access-Control-Expose-Headers'] = 'Count, Link'

      expect(
        validator_class.new(response, block).validate({})
      ).to be_passed
    end

    it "match via regex when failing" do
      validator_class = Class.new(described_class)
      validator_class.class_eval do
        validate_headers do
          expect_header('Access-Control-Expose-Headers', /\bCount\b/)
          expect_header('Access-Control-Expose-Headers', /\bLink\b/)
        end
      end

      env.response_headers['Access-Control-Expose-Headers'] = 'Count'

      expect(
        validator_class.new(response, block).validate({})
      ).to_not be_passed
    end
  end

  context "validate status" do
    it "exact match when passing" do
      validator_class = Class.new(described_class)
      validator_class.class_eval do
        validate_status do
          expect_status(200)
        end
      end

      env.status = 200

      expect(
        validator_class.new(response, block).validate({})
      ).to be_passed
    end

    it "exact match when failing" do
      validator_class = Class.new(described_class)
      validator_class.class_eval do
        validate_status do
          expect_status(404)
        end
      end

      env.status = 200

      expect(
        validator_class.new(response, block).validate({})
      ).to_not be_passed
    end

    it "match via range when passing" do
      validator_class = Class.new(described_class)
      validator_class.class_eval do
        validate_status do
          expect_status(200...300)
        end
      end

      env.status = 204

      expect(
        validator_class.new(response, block).validate({})
      ).to be_passed
    end

    it "match via range when failing" do
      validator_class = Class.new(described_class)
      validator_class.class_eval do
        validate_status do
          expect_status(400...500)
        end
      end

      env.status = 304

      expect(
        validator_class.new(response, block).validate({})
      ).to_not be_passed
    end

    context 'via options' do
      let(:options) { {} }
      let(:validator_class) { Class.new(described_class) }

      it "exact match when passing" do
        options[:status] = 200
        env.status = 200

        expect(
          validator_class.new(response, block, options).validate(options)
        ).to be_passed
      end

      it "exact match when failing" do
        options[:status] = 200
        env.status = 400

        expect(
          validator_class.new(response, block, options).validate(options)
        ).to_not be_passed
      end

      it "match via range when passing" do
        options[:status] = 200...300
        env.status = 204

        expect(
          validator_class.new(response, block, options).validate(options)
        ).to be_passed
      end

      it "match via range when failing" do
        options[:status] = 400...500
        env.status = 200

        expect(
          validator_class.new(response, block, options).validate(options)
        ).to_not be_passed
      end
    end
  end

  context "validate body (json)" do
    context 'when object' do
      let(:options) {
        {
          :properties => {
            :id => 'foobar'
          }
        }
      }

      it "exact match key when passing" do
        validator_class = Class.new(described_class)
        env.body = { 'id' => 'foobar' }
        expect(
          validator_class.new(response, block, options).validate(options)
        ).to be_passed
      end

      it "exact match key when failing" do
        validator_class = Class.new(described_class)
        env.body = { 'id' => 'baz' }
        expect(
          validator_class.new(response, block, options).validate(options)
        ).to_not be_passed
      end
    end

    context 'when array of objects' do
      let(:options) {
        {
          :properties => {
            :foos => [{ :bar => 'baz' }]
          }
        }
      }

      it "exact match when passing" do
        validator_class = Class.new(described_class)
        env.body = { 'foos' => [{ 'bar' => 'baz' }, { 'nothing' => 'real' }] }
        expect(
          validator_class.new(response, block, options).validate(options)
        ).to be_passed
      end

      it "exact match key when failing" do
        validator_class = Class.new(described_class)
        env.body = { 'foos' => [{ 'expected' => 'something else' }] }
        expect(
          validator_class.new(response, block, options).validate(options)
        ).to_not be_passed
      end
    end
  end

  describe "return value" do
    let(:env) do
      Hashie::Mash.new(
        :request_headers => { 'Accept' => TentD::API::MEDIA_TYPE, 'Content-Type' => TentD::API::MEDIA_TYPE },
        :request_body => Yajl::Encoder.encode({ type: 'https://tent.io/types/post/status/v0.1.0', content: { text: 'Hello World' } }),
        :method => :put,
        :url => URI('https://remote.example.com/tent/posts?version=2'),
        :status => 200,
        :response_headers => {
          'etag' => 'ak241',
          'Access-Control-Allow-Origin' => '*',
          'Access-Control-Allow-Methods' => 'GET, POST, DELETE'
        },
        :body => {"id" => "abc123", "content"=>{"text"=>"Hello World"}}
      )
    end

    let(:response_validator) do
      validator = Class.new(described_class)
      validator.class_eval do
        validate_headers do
          expect_header('Access-Control-Allow-Origin', '*')
          expect_header('Access-Control-Allow-Methods', %w( GET POST ), :split => /[^a-z]+/i)
          expect_header('etag', /\A\S+\Z/)
        end

        validate_status do
          expect_status(200)
        end
      end

      validator
    end

    let(:result) do
      response_validator.new(response, block).validate({ :properties => { :id => "abc123" } })
    end

    let(:json) { result.as_json }

    describe "#as_json" do
      it 'should contain request headers' do
        expect(json[:request_headers]).to eql(env[:request_headers])
      end

      it 'should contain request body' do
        expect(json[:request_body]).to eql(env[:request_body])
      end

      it 'should contain request params' do
        expect(json[:request_params]).to eql('version' => '2')
      end

      it 'should contain request path' do
        expect(json[:request_path]).to eql('/tent/posts')
      end

      it 'should contain request url' do
        expect(json[:request_url]).to eql("https://remote.example.com/tent/posts?version=2")
      end

      it 'should contain request method' do
        expect(json[:request_method]).to eql('PUT')
      end

      it 'should contain response headers' do
        expect(json[:response_headers]).to eql(env[:response_headers])
      end

      it 'should contain response body' do
        expect(json[:response_body]).to eql(env[:body])
      end

      it 'should contain response status' do
        expect(json[:response_status]).to eql(env[:status])
      end

      it 'should contain expected response headers' do
        expect(json[:expected_response_headers]).to eql(
          'Access-Control-Allow-Origin' => '*',
          'Access-Control-Allow-Methods' => %w( GET POST ),
          'etag' => '\\A\\S+\\Z'
        )
      end

      it 'should contain expected response body' do
        expect(json[:expected_response_body]).to eql(
          :id => 'abc123',
        )
      end

      it 'should contain expected response status' do
        expect(json[:expected_response_status]).to eql(200)
      end

      it 'should contain passed status' do
        expect(json[:passed]).to be_true
      end
    end
  end
end
