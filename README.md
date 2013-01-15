# TentValidator [![Build Status](https://secure.travis-ci.org/tent/tent-validator.png)](http://travis-ci.org/tent/tent-validator)

Tent protocol validator. **This is a WIP**

## Writing validations

The validation DSL aims to be simple and focused on testing the Tent protocol.

### DSL

```ruby
class TentResponseValidator < TentValidator::ResponseValidator
  register :tent

  validate_headers do
    expect_valid_cors_headers
    expect_header('Content-Type', /\A#{Regexp.escape(TentD::API::MEDIA_TYPE)}/)
  end

  private

  def expect_valid_cors_headers
    expect_header('Access-Control-Allow-Origin', '*')
    expect_header('Access-Control-Allow-Methods', %w( GET POST HEAD PUT DELETE PATCH OPTIONS ), :split => /[^a-z]+/i)
    expect_header('Access-Control-Allow-Headers', %w( Content-Type Authorization ), :split => /[^a-z]+/i)
    expect_header('Access-Control-Expose-Headers', %w( Count Link ), :split => /[^a-z]+/i)
  end
end

class PostsValidation < TentValidator::Validation
  create_post = describe "POST /posts" do
    data = {} # ...
    with_client :app, :server => :remote do |client|
      # expect valid status post json
      expect_response(:tent, :schema => :status, :status => 200...300, :properties => { :entity => get(:entity) }) do
        # uses tent-client-ruby
        res = client.post.create(data)
      end
      set(:post_id, res.body['id']) # res.body['id'] => 'abc123'
    end
  end

  describe "GET /posts/:id", :depends_on => create_post do
    with_client :app, :server => :local do |client|
      # expect valid status post json
      expect_response(:tent, :schema => :status, 200...300, :properties => { :id => get(:post_id), :entity => get(:entity) }) do
        client.post.get(get(:post_id), get(:entity))
      end
    end

    with_client :app, :server => :remote do |client|
      expect_response(:tent, :schema => :status, :status => 200...300, :properties => { :id => get(:post_id) }) do
        client.post.get(get(:post_id))
      end
    end
  end

end

posts_res = PostsValidation.run # => TentValidator::CombinedResults
posts_res.passed? # => true
posts_res.as_json == {
  "GET /posts/:id" => [
    {
      :request_headers => {},
      :request_server => "",
      :request_path => "",
      :request_params => {},
      :request_body => "",

      :response_headers => {},
      :response_server => "",
      :response_path => "",
      :response_params => {},
      :response_body => "",
      :response_status => 200,
      :response_schema_errors => [],

      :expected_response_headers => {
        "Content-Type" => "\\Aapplication/vnd\\.tent\\.v0\\+json", # ...
      },
      :expected_response_body => {
        :id => "abc123",
        :entity => "https://remote.example.com"
      },
      :expected_response_schema => 'status',
      :expected_response_status => "200...300",

      :failed_headers_expectations => [],
      :failed_body_expectations => [],
      :failed_status_expectations => [],

      :passed => true
    }, # ...
  ]
}

TentValidator::Validation.run # run all validations
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
