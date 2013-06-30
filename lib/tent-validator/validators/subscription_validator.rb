module TentValidator

  class SubscriptionValidator < TentValidator::Spec
    require 'tent-validator/validators/support/post_generators'
    include Support::PostGenerators

    require 'tent-validator/validators/support/relationship_importer'
    include Support::RelationshipImporter

    describe "Create Subscription" do
      context "when no existing relationship" do

        shared_example :create_relationship_and_subscription do
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

        set(:subscription_type, %(https://tent.io/types/status/v0#))
        set(:subscription_type_base, %(https://tent.io/types/status/v0))
        set(:subscription_post_type, TentClient::TentType.new("https://tent.io/types/subscription/v0##{get(:subscription_type_base)}").to_s)

        context "entity A" do
          set(:user, TentD::Model::User.generate)
          behaves_as(:create_relationship_and_subscription)
        end

        context "entity B" do
          set(:user, TentD::Model::User.generate)
          behaves_as(:create_relationship_and_subscription)
        end
      end
    end

    describe "Import Subscription"  do
      setup do
        set(:type, "https://example.org/types/status-#{TentD::Utils.timestamp}/v#{rand(1000)}#")
        set(:notification_types, [get(:type)])
        set(:read_types, get(:notification_types))

        user = TentD::Model::User.generate
        set(:user, user)
        set(:entity, user.entity)
        set(:meta_post, user.meta_post.as_json)
      end

      include_import_subscription_examples
      include_import_relationship_examples

      expect_response(:status => 200, :schema => :data) do
        user = get(:user)

        data = generate_status_post
        data[:type] = get(:type)

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
            'Content-Type' => %r{\A#{Regexp.escape(TentD::API::POST_CONTENT_TYPE % get(:type))}}
          )
        end

        manipulate_local_requests(user.id) do |env, app|
          if env['CONTENT_TYPE'].to_s =~ %r{#{Regexp.escape(get(:type))}.+rel=['"][^'"]+notification['"]}
            [200, {}, []]
          else
            app.call(env)
          end
        end

        expected_data = TentD::Utils::Hash.deep_dup(data)
        expected_data.delete(:permissions)
        expect_properties(:post => expected_data)

        clients(:app_auth).post.create(data)
      end
    end

    describe "Delete Subscription" do
      # setup relationship with subscription
      # delete subscription
      # assert posts are not received for the subscription

      setup do
        set(:type, "https://example.org/types/status-#{TentD::Utils.timestamp}/v#{rand(1000)}#")
        set(:notification_types, [get(:type)])
        set(:read_types, get(:notification_types))

        user = TentD::Model::User.generate
        set(:user, user)
        set(:entity, user.entity)
        set(:meta_post, user.meta_post.as_json)
      end

      include_import_subscription_examples
      include_import_relationship_examples

      # make sure we can get the subscription
      expect_response(:status => 200, :schema => :data) do
        subscription = get(:subscription)

        expect_properties(:post => subscription)

        clients(:app_auth).post.get(subscription[:entity], subscription[:id]) do |request|
          request['Cache-Control'] = 'only-if-cached'
        end
      end

      # delete the subscription
      expect_response(:status => 200) do
        subscription = get(:subscription)

        remote_credentials = get(:remote_credentials)
        client = clients(:custom, remote_credentials[:content].merge(:id => remote_credentials[:id]))

        delete_post = {
          :id => TentD::Utils.random_id,
          :entity => get(:entity),
          :type => "https://tent.io/types/delete/v0#",
          :refs => [{
            :entity => subscription[:entity],
            :post => subscription[:id]
          }]
        }

        client.post.update(delete_post[:entity], delete_post[:id], delete_post, {}, :notification => true)
      end

      # make sure the subscription is deleted
      expect_response(:status => 404, :schema => :error) do
        subscription = get(:subscription)

        clients(:app_auth).post.get(subscription[:entity], subscription[:id]) do |request|
          request['Cache-Control'] = 'only-if-cached'
        end
      end

      # create a post that would we delivered to the subscriber if the subscription still existed
      # assert it is not delivered
      expect_response(:status => 200, :schema => :data) do
        user = get(:user)

        data = generate_status_post
        data[:type] = get(:type)

        expect_async_request(
          :method => "PUT",
          :url => %r{\A#{Regexp.escape(get(:user).entity)}},
          :path => %r{\A/posts/#{Regexp.escape(URI.encode_www_form_component(TentValidator.remote_entity_uri))}/[^/]+\Z},
          :negative_expectation => true
        ) do
          expect_schema(:post)
          expect_headers(
            'Content-Type' => %r{\brel=['"]#{Regexp.escape("https://tent.io/rels/notification")}['"]}
          )
          expect_headers(
            'Content-Type' => %r{\A#{Regexp.escape(TentD::API::POST_CONTENT_TYPE % get(:type))}}
          )
        end

        manipulate_local_requests(user.id) do |env, app|
          if env['CONTENT_TYPE'].to_s =~ %r{#{Regexp.escape(get(:type))}.+rel=['"][^'"]+notification['"]}
            [200, {}, []]
          else
            app.call(env)
          end
        end

        expected_data = TentD::Utils::Hash.deep_dup(data)
        expected_data.delete(:permissions)
        expect_properties(:post => expected_data)

        clients(:app_auth).post.create(data)
      end
    end

  end

  TentValidator.validators << SubscriptionValidator
end
