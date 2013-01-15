require "spec_helper"

describe TentValidator::ValidationRunner do
  let(:http_stubs) { Array.new }

  it "should run all example_groups and dependent example_groups" do
    http_stubs << stub_request(:get, "https://remote.example.org").to_return(:body => 'Tent!')
    http_stubs << stub_request(:post, "https://remote.example.org/foo").with(:body => 'Tent!').to_return(:body => 'Foo Bar')

    remote_validation = Class.new(TentValidator::Validation)
    remote_validation.class_eval do
      hello_world = describe "GET /" do
        with_client :app, :server => :remote do
          expect_response :void do
            response = client.http.get('/')
            set(:hello_world, response.body)
            response
          end
        end
      end

      describe "POST /foo", :depends_on => hello_world do
        with_client :app, :server => :remote do
          expect_response :void do
            client.http.post('/foo', get(:hello_world))
          end
        end
      end
    end
    res = described_class.new(remote_validation).run
    expect(res).to be_passed
  end
end
