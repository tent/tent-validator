module TentValidator

  class SubscriptionValidator < TentValidator::Spec
    require 'tent-validator/validators/support/post_generators'
    include Support::PostGenerators

    describe "Create Subscription" do
      context "when no existing relationship" do

        set(:user, TentD::Model::User.generate)
        set(:subscription_type, %(https://tent.io/types/status/v0#))
        set(:subscription_type_base, %(https://tent.io/types/status/v0))

        ##
        # Setup asyc request expectation for relationship# post
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
            'Content-Type' => %r{\A#{Regexp.escape(TentD::API::POST_CONTENT_TYPE % %(https://tent.io/types/relationship/v0#))}}
          )
        end.expect_response(:status => 200, :schema => :data) do
          expect_schema(:post, '/post')
          expect_headers(
            'Content-Type' => TentD::API::POST_CONTENT_TYPE % %(https://tent.io/types/relationship/v0#)
          )
        end

        ##
        # Setup async request expectation for status# post
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
            'Content-Type' => %r{\A#{Regexp.escape(TentD::API::POST_CONTENT_TYPE % get(:subscription_type))}}
          )
        end.expect_response(:status => 200, :schema => :data) do
          expect_schema(:post, '/post')
          expect_headers(
            'Content-Type' => TentD::API::POST_CONTENT_TYPE % get(:subscription_type)
          )
        end

        ##
        # Create subscription on local server (should trigger relationship init)
        expect_response(:status => 200, :schema => :data) do
          data = {
            :type => %(https://tent.io/types/subscription/v0##{URI.encode_www_form_component(get(:subscription_type_base))}),
            :mentions => [{ 'entity' => TentValidator.remote_entity_uri }],
            :content => {
              :type => get(:subscription_type)
            },
            :permissions => {
              :entities => [TentValidator.remote_entity_uri]
            }
          }
          clients(:app, :server => :local, :user => get(:user)).post.create(data)
        end

        ##
        # Create post of type subscribed on remote server (should trigger notification)
        expect_response(:status => 200, :schema => :data) do
          data = generate_status_post(is_public=true)
          clients(:app).post.create(data)
        end

      end
    end

  end

  TentValidator.validators << SubscriptionValidator
end
