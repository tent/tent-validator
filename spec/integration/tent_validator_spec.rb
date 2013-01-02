require 'spec_helper'

class TestHelloWorldValidator < TentValidator::ResponseValidator
  register :test_hello_world

  def validate(response, options)
    if response.body == 'hello world'
      true
    else
      [false, "expected \"hello world\", got(#{response.body.inspect})"]
    end
  end
end

describe TentValidator do
  let(:http_stubs) { Array.new }

  it "should test successful response from remote server" do
    TentValidator.remote_server = "https://remote.example.org/tent"
    TentValidator.remote_auth_details = {
      :mac_key_id => 'mac-key-id',
      :mac_algorithm => 'hmac-sha-256',
      :mac_key => 'mac-key'
    }

    http_stubs << stub_request(:get, "https://remote.example.org").to_return(:body => 'hello world')

    remote_validation = Class.new(TentValidator::Validation)
    remote_validation.class_eval do
      describe "GET /" do
        with_client :app, :server => :remote do
          expect_response :test_hello_world do
            client.http.get('/')
          end
        end
      end
    end
    res = remote_validation.run
    expect(res).to be_passed

    expect(res.first).to be_a(TentValidator::Results)

    # TODO: test res.as_json

    http_stubs.each { |s|
      expect(s).to have_been_requested
    }
  end

  it "should test unsuccessful response from remote server"

  it "should test successful response from local server"

  it "should test unsuccessful response from local server"
end
