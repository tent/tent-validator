module TentValidator
  class PostsFeedValidator < TentValidator::Spec

    SetupFailure = Class.new(StandardError)

    require 'tent-validator/validators/support/post_generators'
    include Support::PostGenerators

    def create_posts
      client = clients(:app)
      posts_attribtues = [generate_status_post, generate_random_post, generate_status_reply_post, generate_status_post]
      post_types = posts_attribtues.map { |a| a[:type] }.reverse

      posts = []
      posts_attribtues.each do |post|
        res = client.post.create(post)
        raise SetupFailure.new("Failed to create post: #{res.status}\n#{res.body.inspect}") unless res.success?
        posts << res.body
      end
      set(:posts, posts)

      set(:post_types, post_types)
    end

    describe "GET posts_feed", :before => :create_posts do
      context "without params" do
        expect_response(:status => 200, :schema => :data) do
          expect_properties(:posts => get(:post_types).map { |type| { :type => type } })

          clients(:app).post.list
        end
      end

      context "with type param" do
        expect_response(:status => 200, :schema => :data) do
          types = get(:post_types)
          types = [types.first, types.last]

          expect_properties(:posts => types.map { |type| { :type => type } })

          clients(:app).post.list(:types => types)
        end

        context "when using fragment wildcard" do
          expect_response(:status => 200, :schema => :data) do
            type = TentClient::TentType.new('https://tent.io/types/status/v0')
            expected_types = get(:post_types).select { |t|
              TentClient::TentType.new(t).base == type.base
            }.map { |t| { :type => t } }

            expect_properties(:posts => expected_types)

            clients(:app).post.list(:types => [type.to_s(:fragment => false)])
          end
        end
      end

      context "with entities param" do
        context "when no matching entities" do
          expect_response(:status => 200, :schema => :data) do
            expect_properties(:posts => [])

            clients(:app).post.list(:entities => "https://fictitious.entity.example.org")
          end
        end

        context "when matching entities" do
          expect_response(:status => 200, :schema => :data) do
            entities = get(:posts).map { |p| p['entity'] }
            expect_properties(:posts => entities.map { |e| { :entity => e } })

            clients(:app).post.list(:entities => entities.uniq.join(','))
          end
        end

        # TODO: validate feed with entities param (with proxy)
      end

      # default limit is 25, make sure there are more than 25 posts (create_posts already called once and it creates 4 posts)
      context "when using default limit", :before => 6.times.map { :create_posts } do
        expect_response(:status => 200, :schema => :data) do
          expect_property_length("/posts", 25)

          clients(:app).post.list
        end
      end
    end
  end

  TentValidator.validators << PostsFeedValidator
end
