module TentValidator

  class SubscriptionValidator < TentValidator::Spec
    require 'tent-validator/validators/support/post_generators'
    include Support::PostGenerators

    describe "Create Subscription" do
      context "when no existing relationship" do

        set(:user, TentD::Model::User.generate)
        set(:subscription_type, %(https://tent.io/types/status/v0#))
        set(:subscription_type_base, %(https://tent.io/types/status/v0))
        set(:subscription_post_type, TentClient::TentType.new("https://tent.io/types/subscription/v0##{get(:subscription_type_base)}").to_s)

        ##
        # Setup asyc request expectation for relationship#initial post
        expect_async_request(
          :method => "PUT",
          :url => %r{\A#{Regexp.escape(get(:user).entity)}},
          :path => %r{\A/posts/#{Regexp.escape(URI.encode_www_form_component(TentValidator.remote_entity_uri))}/[^/]+\Z}
        ) do
          expect_schema(:post)
          expect_headers(
            'Content-Type' => %r{\brel=['"]#{Regexp.escape("https://tent.io/rels/notification")}['"]}
          )
          expect_headers(
            'Content-Type' => %r{\A#{Regexp.escape(TentD::API::POST_CONTENT_TYPE % %(https://tent.io/types/relationship/v0#initial))}}
          )
        end.expect_response(:status => 200, :schema => :data) do
          expect_schema(:post, '/post')
          expect_headers(
            'Content-Type' => TentD::API::POST_CONTENT_TYPE % %(https://tent.io/types/relationship/v0#initial)
          )
        end

        ##
        # Setup asyc request expectation for subscription
        expect_async_request(
          :method => "PUT",
          :url => %r{\A#{Regexp.escape(get(:user).entity)}},
          :path => %r{\A/posts/#{Regexp.escape(URI.encode_www_form_component(TentValidator.remote_entity_uri))}/[^/]+\Z}
        ) do
          expect_schema(:post)
          expect_headers(
            'Content-Type' => %r{\brel=['"]#{Regexp.escape("https://tent.io/rels/notification")}['"]}
          )
          expect_headers(
            'Content-Type' => %r{\A#{Regexp.escape(TentD::API::POST_CONTENT_TYPE % get(:subscription_post_type))}}
          )
        end.expect_response(:status => 200, :schema => :data) do
          expect_schema(:post, '/post')
          expect_headers(
            'Content-Type' => TentD::API::POST_CONTENT_TYPE % get(:subscription_post_type)
          )
        end

        ##
        # Create subscription on remote server (should trigger relationship init and send us the subscription)
        expect_response(:status => 200, :schema => :data) do
          data = {
            :type => get(:subscription_post_type),
            :mentions => [{ 'entity' => get(:user).entity }],
            :content => {
              :type => get(:subscription_type)
            },
            :permissions => {
              :entities => [get(:user).entity]
            }
          }
          clients(:app_auth).post.create(data)
        end

      end
    end

  end

  TentValidator.validators << SubscriptionValidator
end
