module TentValidator
  class PostsFeedEdgeValidator < TentValidator::Spec

    require 'tent-validator/validators/support/post_generators'
    include Support::PostGenerators

    describe "GET posts_feed" do
      context "when multiple versions of a post" do

        # create a post
        expect_response(:status => 200, :schema => :data) do
          expect_schema(:post, '/post')

          data = generate_status_post
          clients(:app_auth).post.create(data)
        end.after do |response, results, validator|
          if results.any? { |r| !r[:valid] }
            raise SetupFailure.new("Failed to create post", response, results, validator)
          else
            set(:post, TentD::Utils::Hash.symbolize_keys(response.body['post']))
          end
        end

        # create new version of post
        expect_response(:status => 200, :schema => :data) do
          expect_schema(:post, '/post')

          post = get(:post)

          data = TentD::Utils::Hash.deep_dup(post)
          data[:content] = generate_status_post[:content]
          data[:version] = {
            :parents => [{ version: post[:version][:id] }]
          }

          clients(:app_auth).post.update(post[:entity], post[:id], data)
        end.after do |response, results, validator|
          if results.any? { |r| !r[:valid] }
            raise SetupFailure.new("Failed to create post", response, results, validator)
          else
            set(:latest_post, TentD::Utils::Hash.symbolize_keys(response.body['post']))
          end
        end

        # make sure only the latest version is in the feed
        expect_response(:status => 200, :schema => :data) do
          post = get(:post)
          latest_post = get(:latest_post)

          expect_properties(:posts => [
            { :id => latest_post[:id], :version => { :id => latest_post[:version][:id] } },
            { :id => not_equal(post[:id]), :version => { :id => not_equal(post[:version][:id]) } }
          ])

          clients(:app_auth).post.list(:limit => 3)
        end

      end
    end
  end

  TentValidator.validators << PostsFeedEdgeValidator
end
