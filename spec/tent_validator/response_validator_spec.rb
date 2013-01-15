require 'spec_helper'

describe TentValidator::ResponseValidator do
  let(:env) { Hashie::Mash.new(:status => 200, :response_headers => {}, :body => '') }
  let(:response) { Faraday::Response.new(env) }
  let(:block) { lambda {} }

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
  end

  it "should validate body"
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

describe TentValidator::ResponseValidator::Result do
  let(:env) { Hashie::Mash.new(
    :request_headers => { 'Accept' => TentD::API::MEDIA_TYPE, 'Content-Type' => TentD::API::MEDIA_TYPE },
    :request_body => Yajl::Encoder.encode({ type: 'https://tent.io/types/post/status/v0.1.0', content: { text: 'Hello World' } }),
    :method => :put,
    :url => URI('https://remote.example.com/tent/posts?version=2'),
    :status => 200,
    :response_headers => { 'content-type' => TentD::API::MEDIA_TYPE, 'etag' => '1234' },
    :body => {"entity"=>"https://demo.example.com", "licenses"=>[], "content"=>{"text"=>"Hello World"}, "published_at"=>1357665780, "permissions"=>{"groups"=>[], "entities"=>{}, "public"=>false}, "id"=>"8Ow_LxdKerMwNRuSVUxcJg", "updated_at"=>1357665780, "received_at"=>1357665780, "attachments"=>[], "type"=>"https://tent.io/types/post/status/v0.1.0", "version"=>1, "app"=>{"url"=>"https://apps.example.org/demo", "name"=>"Demo App"}, "mentions"=>[]}
  ) }
  let(:response) { Faraday::Response.new(env) }
  let(:expectations) {
    [
      TentValidator::ResponseValidator::Expectation.new(
        :headers => { 'Content-Type' => TentD::API::MEDIA_TYPE }
      ),
      TentValidator::ResponseValidator::Expectation.new(
        :headers => { 'etag' => /\A\S+\Z/ },
        :body => {
          :id => /\A\S+\Z/,
          :entity => "https://demo.example.com",
          :content => {
            :text => "Hello World"
          },
          :version => 1
        }
      ),
      TentValidator::ResponseValidator::Expectation.new(
        :body => {
          :published_at => /\A\d+\Z/,
          :updated_at => /\A\d+\Z/,
          :received_at => /\A\d+\Z/,
          :permissions => {
            :public => false
          },
          :mentions => []
        }
      ),
      TentValidator::ResponseValidator::Expectation.new(
        :status => 200
      )
    ]
  }
  let(:result) { described_class.new(response: response, expectations: expectations) }

  describe "#as_json" do
    let(:json) { result.as_json }

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
        'Content-Type' => TentD::API::MEDIA_TYPE,
        'etag' => /\A\S+\Z/
      )
    end

    it 'should contain expected response body' do
      expect(json[:expected_response_body]).to eql(
        :id => /\A\S+\Z/,
        :entity => "https://demo.example.com",
        :content => {
          :text => "Hello World"
        },
        :version => 1,
        :published_at => /\A\d+\Z/,
        :updated_at => /\A\d+\Z/,
        :received_at => /\A\d+\Z/,
        :permissions => {
          :public => false
        },
        :mentions => []
      )
    end

    context 'when expected response body is a string' do
      let(:body) { Yajl::Encoder.encode(env[:body]) }
      let(:expectations) {
        [
          TentValidator::ResponseValidator::Expectation.new(
            :body => body
          ),
          TentValidator::ResponseValidator::Expectation.new(status: 200)
        ]
      }

      it 'should contain expected response body' do
        expect(json[:expected_response_body]).to eql(body)
      end
    end

    it 'should contain expected response status' do
      expect(json[:expected_response_status]).to eql(200)
    end

    it 'should contain passed status' do
      expect(json[:passed]).to be_true
    end
  end
end
