module TentValidator
  class PostsFeedValidator < TentValidator::Spec

    SetupFailure = Class.new(StandardError)

    require 'tent-validator/validators/support/post_generators'
    include Support::PostGenerators

    def create_posts
      client = clients(:app)
      posts_attribtues = [generate_status_post, generate_random_post, generate_status_post]
      post_types = posts_attribtues.map { |a| a[:type] }.reverse

      posts_attribtues.each do |post|
        res = client.post.create(post)
        raise SetupFailure.new("Failed to create post: #{res.status}\n#{res.body.inspect}") unless res.success?
      end

      set(:post_types, post_types)
    end

    # TODO: validate raw feed (no params)
    describe "GET /posts", :before => :create_posts do
      expect_response(:status => 200, :schema => :data) do
        expect_properties(:posts => get(:post_types).map { |type| { :type => type } })

        clients(:app).post.list
      end
    end

    # TODO: validate feed with type param

    # TODO: validate feed with entity param (no proxy)
  end

  TentValidator.validators << PostsFeedValidator
end
