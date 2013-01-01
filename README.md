# TentValidator

Tent protocol validator. **This is a WIP**

## Writing validations

The validation DSL is very similar in appearance to RSpec, but is simpler and focused on testing the Tent protocol.

### DSL

```ruby
class PostResponseValidator < TentValidator::ResponseValidator
  register :post

  # should return true if valid
  # should return [false, "Error description"] if invalid
  def validate(response)
    # ...
  end
end

class StatusPostResponseValidator < PostResponseValidator
  register :status_post

  def validate(response)
    super
    # ...
  end
end

class PostsValidation < TentValidator::Validation
  create_post = describe "POST /posts" do
    data = {} # ...
    with_client :app, :server => :remote do |client|
      # expect valid status post json
      expect_response(:status_post, :entity => get(:entity)) do
        res = client.post.create(data)
      end
      set(:post_id, res.body['id'])
    end
  end

  describe "GET /posts/:id", :depends_on => create_post do
    with_client :app, :server => :local do |client|
      # expect valid status post json
      expect_response(:status_post, :id => get(:post_id), :entity => get(:entity)) do
        # uses tent-client-ruby
        client.post.get(get(:post_id), get(:entity))
      end
    end

    with_client :app, :server => :remote do |client|
      expect_response(:status_post, get(:post_id)) do
        client.post.get(get(:post_id))
      end
    end
  end

end

posts_res = PostsValidation.run # => TentValidator::Results
posts_res.passed? # => true
posts_res.to_hash == {
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

      :expected_response_headers => TentValidator::Expectation,
      :expected_response_server => TentValidator::Expectation,
      :expected_response_path => TentValidator::Expectation,
      :expected_response_params => TentValidator::Expectation,
      :expected_response_body => TentValidator::Expectation,
      :expected_response_status => TentValidator::Expectation,

      :passed => true
    }, # ...
  ]
}
posts_res.first # => TentValidator::Result

all_res = TentValidator::Validation.run # => TentValidator::Results
all_res.passed? # => true
all_res.to_hash == [
  {
    "GET /posts/:id" => [] # ...
  }
]

all_res.first == posts_res # => true

TentValidator::Validation.run(
  :on_failure => lambda { |result| }, # result.class == TentValidator::Result
  :on_success => lambda { |result| }, # result.class == TentValidator::Result
  :on_error => lambda { |exception| } # called when unexpected Ruby exception caught
)
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
