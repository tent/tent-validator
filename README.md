# TentValidator [![Build Status](https://secure.travis-ci.org/tent/tent-validator.png)](http://travis-ci.org/tent/tent-validator)

Tent protocol validator. **This is a WIP**

## Running

You will need redis, postgres, and a JavaScript runtime (eg. nodejs)

**Environment Variables**

```
VALIDATOR_DATABASE_URL=postgres://localhost/tent-validator
TENT_DATABASE_URL=postgres://localhost/tent-validator-tentd
VALIDATOR_NOTIFICATION_URL=http://localhost:9292/webhooks
COOKIE_SECRET=8a7f53069591896fa076227588c9b64b
REDIS_URL=redis://127.0.0.1:6379/0
REDIS_NAMESPACE=tent-validator
```

### Start webserver

```
bundle exec puma -p 9292
```

### Start Sidekiq

```
bundle exec sidekiq -r ./boot.rb
```

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
    # expect valid status post json
    expect_response(:tent, :schema => :status, :post_status => 200...300, :properties => { :entity => get(:entity) }) do
      # uses tent-client-ruby
      clients(:app, server: :remote).post.create(data)
    end.after do |result|
      if result.response.success?
        set(:post_id, res.body['id']) # res.body['id'] => 'abc123'
      end
    end
  end

  describe "GET /posts/:id", :depends_on => create_post do
    # expect valid status post json
    expect_response(:tent, :schema => :post_status, 200...300, :properties => { :id => get(:post_id), :entity => get(:entity) }) do
      clients(:app, server: :local).post.get(get(:post_id), get(:entity))
    end

    expect_response(:tent, :schema => :status, :status => 200...300, :properties => { :id => get(:post_id) }) do
      clients(:app, server: :remote).post.get(get(:post_id))
    end
  end
end

posts_res = PostsValidation.run # => TentValidator::Results
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
      :expected_response_body_excludes => [],
      :expected_response_schema => 'post_status',
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

### Creating tentd users

The validator is backed by a multi-tenent instance of tentd. It is used for testing interaction between servers.

```ruby
# Create new user
user = TentD::Model::User.generate
user.entity # => http://localhost:9292/8f05dbf7abf57a0363279032a4cbdf72/tent

# Create app authorization for user
authorization_attributes = {}
auth = user.create_authorization(authorization_attributes) # => TentD::Model::AppAuthorization
auth.auth_details # => { :mac_key_id => ... }
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
