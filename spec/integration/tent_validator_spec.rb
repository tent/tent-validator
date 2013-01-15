require 'spec_helper'

describe TentValidator do
  let(:http_stubs) { Array.new }

  before do
    TentValidator.remote_server = "https://remote.example.org/tent"
    TentValidator.remote_auth_details = {
      :mac_key_id => 'mac-key-id',
      :mac_algorithm => 'hmac-sha-256',
      :mac_key => 'mac-key'
    }
  end

  it "should test successful response from remote server" do
    http_stubs << stub_request(:post, "https://remote.example.org/foo?bar=baz").to_return(:body => Yajl::Encoder.encode({ :id => 'Tent!' }), :headers => { 'Content-Type' => TentD::API::MEDIA_TYPE })

    remote_validation = Class.new(TentValidator::Validation)
    remote_validation.class_eval do
      describe "GET /" do
        with_client :app, :server => :remote do
          expect_response :void, :properties => { :id => 'Tent!' } do
            client.http.post('/foo?bar=baz', { foo: 'bar' })
          end
        end
      end
    end
    res = remote_validation.run
    expect(res).to be_passed

    expect(res).to be_a(TentValidator::Results)

    http_stubs.each { |s|
      expect(s).to have_been_requested
    }
  end

  it "should test unsuccessful response from remote server" do
    http_stubs << stub_request(:post, "https://remote.example.org/foo?bar=baz").to_return(:body => Yajl::Encoder.encode({ :id => 'Foo Bar' }), :headers => { 'Content-Type' => TentD::API::MEDIA_TYPE })

    remote_validation = Class.new(TentValidator::Validation)
    remote_validation.class_eval do
      describe "GET /" do
        with_client :app, :server => :remote do
          expect_response :void, :properties => { :id => 'Tent!' } do
            client.http.post('/foo?bar=baz', { foo: 'bar' })
          end
        end
      end
    end
    res = remote_validation.run
    expect(res).to_not be_passed

    expect(res).to be_a(TentValidator::Results)

    http_stubs.each { |s|
      expect(s).to have_been_requested
    }
  end

  it "should test successful response from local server" do
    local_validation = Class.new(TentValidator::Validation)
    local_validation.class_eval do
      describe "GET /" do
        with_client :app, :server => :local do
          expect_response :void do
            client.http.get('/')
          end
        end
      end
    end
    res = local_validation.run
    expect(res).to be_passed
  end

  it "should test unsuccessful response from local server" do
    local_validation = Class.new(TentValidator::Validation)
    local_validation.class_eval do
      describe "GET /" do
        with_client :app, :server => :local do
          expect_response :void, :status => 200 do
            client.http.get('/foo/bar/baz')
          end
        end
      end
    end
    res = local_validation.run
    expect(res).to_not be_passed
  end
end
