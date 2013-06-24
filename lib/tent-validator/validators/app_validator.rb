module TentValidator
  class AppValidator < TentValidator::Spec
    require 'tent-validator/validators/support/post_generators'
    include Support::PostGenerators

    require 'tent-validator/validators/support/app_post_generators'
    include Support::AppPostGenerators

    describe "App notifications" do
      # create app on remote server with generated webhook url (via import)
      # create post for which app is registered to be notified about
      # set async expectation that app receives post notification to webhook url

      shared_example :setup do
        # import app
        expect_response(:status => 200, :schema => :data) do
          webhook = generate_webhook
          set(:webhook, webhook)

          timestamp = TentD::Utils.timestamp
          data = generate_app_post.merge(
            :entity => TentValidator.remote_entity_uri,
            :id => TentD::Utils.random_id,
            :published_at => timestamp,
            :received_at => timestamp,
            :version => {
              :published_at => timestamp,
              :received_at => timestamp
            }
          )
          data[:content][:notification_url] = webhook.url
          data[:content][:notification_post_types] = [get(:post_type)]
          data[:content][:post_types][:read] = get(:read_types)

          data[:version][:id] = generate_version_signature(data)

          set(:app, data)

          expect_properties(:post => data)

          clients(:app_auth).post.update(data[:entity], data[:id], data, {}, :import => true)
        end.after do |response, results, validator|
          if results.any? { |r| !r[:valid] }
            raise SetupFailure.new("Failed to import app", response, results, validator)
          end
        end

        # import app credentials
        expect_response(:status => 200, :schema => :data) do
          app = get(:app)

          timestamp = TentD::Utils.timestamp
          data = generate_credentials_post(app[:type]).merge(
            :entity => TentValidator.remote_entity_uri,
            :id => TentD::Utils.random_id,
            :published_at => timestamp,
            :received_at => timestamp,
            :version => {
              :published_at => timestamp,
              :received_at => timestamp
            },
            :refs => [
              { :post => app[:id], :type => app[:type] }
            ],
            :mentions => [
              { :post => app[:id], :type => app[:type] }
            ]
          )

          data[:version][:id] = generate_version_signature(data)

          set(:app_credentials, data)

          expect_properties(:post => data)

          clients(:app_auth).post.update(data[:entity], data[:id], data, {}, :import => true)
        end.after do |response, results, validator|
          if results.any? { |r| !r[:valid] }
            raise SetupFailure.new("Failed to import app credentials", response, results, validator)
          end
        end

        # update app to mention credentials via import app version
        expect_response(:status => 200, :schema => :data) do
          app = get(:app)
          app_credentials = get(:app_credentials)

          app[:mentions] = [
            { :post => app_credentials[:id], :type => app_credentials[:type] }
          ]

          timestamp = TentD::Utils.timestamp

          app[:published_at] = timestamp
          app[:received_at] = timestamp

          app[:version] = {
            :published_at => timestamp,
            :received_at => timestamp,
            :parents => [
              { :version => app[:version][:id] }
            ]
          }

          app[:version][:id] = generate_version_signature(app)

          expect_properties(:post => app)

          clients(:app_auth).post.update(app[:entity], app[:id], app, {}, :import => true)
        end.after do |response, results, validator|
          if results.any? { |r| !r[:valid] }
            raise SetupFailure.new("Failed to import app version", response, results, validator)
          end
        end

        # import app-auth
        expect_response(:status => 200, :schema => :data) do
          app = get(:app)

          timestamp = TentD::Utils.timestamp
          data = generate_app_auth_post.merge(
            :entity => TentValidator.remote_entity_uri,
            :id => TentD::Utils.random_id,
            :published_at => timestamp,
            :received_at => timestamp,
            :version => {
              :published_at => timestamp,
              :received_at => timestamp
            },
            :refs => [
              { :post => app[:id], :type => app[:type] }
            ],
            :mentions => [
              { :post => app[:id], :type => app[:type] }
            ]
          )
          data[:content][:post_types] = app[:content][:post_types]
          data[:content][:scopes] = app[:content][:scopes]

          data[:version][:id] = generate_version_signature(data)

          set(:app_auth, data)

          expect_properties(:post => data)

          clients(:app_auth).post.update(data[:entity], data[:id], data, {}, :import => true)
        end.after do |response, results, validator|
          if results.any? { |r| !r[:valid] }
            raise SetupFailure.new("Failed to import app-auth", response, results, validator)
          end
        end

        # import app-auth credentials
        expect_response(:status => 200, :schema => :data) do
          app_auth = get(:app_auth)

          timestamp = TentD::Utils.timestamp
          data = generate_credentials_post(app_auth[:type]).merge(
            :entity => TentValidator.remote_entity_uri,
            :id => TentD::Utils.random_id,
            :published_at => timestamp,
            :received_at => timestamp,
            :version => {
              :published_at => timestamp,
              :received_at => timestamp
            },
            :refs => [
              { :post => app_auth[:id], :type => app_auth[:type] }
            ],
            :mentions => [
              { :post => app_auth[:id], :type => app_auth[:type] }
            ]
          )

          data[:version][:id] = generate_version_signature(data)

          set(:app_auth_credentials, data)

          expect_properties(:post => data)

          clients(:app_auth).post.update(data[:entity], data[:id], data, {}, :import => true)
        end.after do |response, results, validator|
          if results.any? { |r| !r[:valid] }
            raise SetupFailure.new("Failed to import app-auth credentials", response, results, validator)
          end
        end

        # update app-auth to mention credentials via import app-auth version
        expect_response(:status => 200, :schema => :data) do
          app_auth = get(:app_auth)
          app_auth_credentials = get(:app_auth_credentials)

          app_auth[:mentions] << { :post => app_auth_credentials[:id], :type => app_auth_credentials[:type] }

          timestamp = TentD::Utils.timestamp

          app_auth[:published_at] = timestamp
          app_auth[:received_at] = timestamp

          app_auth[:version] = {
            :published_at => timestamp,
            :received_at => timestamp,
            :parents => [
              { :version => app_auth[:version][:id] }
            ]
          }

          app_auth[:version][:id] = generate_version_signature(app_auth)

          clients(:app_auth).post.update(app_auth[:entity], app_auth[:id], app_auth, {}, :import => true)
        end.after do |response, results, validator|
          if results.any? { |r| !r[:valid] }
            raise SetupFailure.new("Failed to import app-auth version", response, results, validator)
          end
        end

        # expect app credentials to work
        expect_response(:status => 200, :schema => :data) do
          app = get(:app)
          app_credentials = get(:app_credentials)

          client = clients(:custom, TentD::Utils::Hash.slice(app_credentials[:content], :hawk_key, :hawk_algorithm).merge(:id => app_credentials[:id]))

          expected_data = TentD::Utils::Hash.deep_dup(app)
          expected_data.delete(:received_at)
          expected_data[:version].delete(:received_at)
          expect_properties(:post => expected_data)

          client.post.get(app[:entity], app[:id])
        end.after do |response, results, validator|
          if results.any? { |r| !r[:valid] }
            raise SetupFailure.new("Failed to fetch app with imported app credentials", response, results, validator)
          end
        end

        # expect app-auth credentials to work
        expect_response(:status => 200, :schema => :data) do
          app = get(:app)
          app_auth_credentials = get(:app_credentials)

          client = clients(:custom, TentD::Utils::Hash.slice(app_auth_credentials[:content], :hawk_key, :hawk_algorithm).merge(:id => app_auth_credentials[:id]))

          expected_data = TentD::Utils::Hash.deep_dup(app)
          expected_data.delete(:received_at)
          expected_data[:version].delete(:received_at)
          expect_properties(:post => expected_data)

          client.post.get(app[:entity], app[:id])
        end.after do |response, results, validator|
          if results.any? { |r| !r[:valid] }
            raise SetupFailure.new("Failed to fetch app with imported app-auth credentials", response, results, validator)
          end
        end
      end

      shared_example :async_notification do
        # create post and expect async notification
        expect_response(:status => 200, :schema => :data) do
          data = generate_status_post(get(:public))
          data[:type] = get(:post_type)

          set(:post, data)

          expected_data = TentD::Utils::Hash.deep_dup(data)
          expected_data.delete(:permissions) if get(:public)
          expect_properties(:post => expected_data)

          ##
          # Setup async request expectation for webhook
          webhook = get(:webhook)
          expect_async_request(
            :method => "PUT",
            :url => webhook.url
          ) do
            expect_schema(:post)
            expect_headers(
              'Content-Type' => %r{\brel=['"]#{Regexp.escape("https://tent.io/rels/notification")}['"]}
            )
            expect_headers(
              'Content-Type' => %r{\A#{Regexp.escape(TentD::API::POST_CONTENT_TYPE % data[:type])}}
            )
            expect_headers(
              'Authorization' => %r{\bid=['"]#{Regexp.escape(get(:app_credentials)[:id])}['"]}
            )
          end.expect_response(:status => 200) {}

          clients(:app_auth).post.create(data)
        end
      end

      shared_example :no_async_notification do
        # create post and expect async notification
        expect_response(:status => 200, :schema => :data) do
          data = generate_status_post(get(:public))
          data[:type] = get(:post_type)

          set(:post, data)

          expected_data = TentD::Utils::Hash.deep_dup(data)
          expected_data.delete(:permissions) if get(:public)
          expect_properties(:post => expected_data)

          ##
          # Setup async negative request expectation for webhook
          webhook = get(:webhook)
          expect_async_request(
            :method => "PUT",
            :url => webhook.url,
            :negative_expectation => true
          )

          clients(:app_auth).post.create(data)
        end
      end

      context "when full authorization" do
        setup do
          set(:read_types, %w( all ))
        end

        context "when post is public" do
          setup do
            set(:public, true)
            set(:post_type, "https://tent.io/types/status/v0#reply")
          end

          behaves_as(:setup)
          behaves_as(:async_notification)
        end

        context "when post is private" do
          setup do
            set(:public, false)
            set(:post_type, "https://tent.io/types/status/v0#")
          end

          behaves_as(:setup)
          behaves_as(:async_notification)
        end
      end

      context "when authorized for explicit type with wildcard fragment" do
        setup do
          set(:read_types, %w( https://tent.io/types/status/v0 ))
        end

        context "when post is public" do
          setup do
            set(:public, true)
          end

          context "when post matches authorized type" do
            setup do
              set(:post_type, "https://tent.io/types/status/v0#reply")
            end

            behaves_as(:setup)
            behaves_as(:async_notification)
          end

          context "when post doesn't match authorized type" do
            setup do
              set(:post_type, "https://tent.example.org/types/fictitious/v0#")
            end

            behaves_as(:setup)
            behaves_as(:no_async_notification)
          end
        end

        context "when post is private" do
          setup do
            set(:public, false)
          end

          context "when post matches authorized type" do
            setup do
              set(:post_type, "https://tent.io/types/status/v0#reply")
            end

            behaves_as(:setup)
            behaves_as(:async_notification)
          end

          context "when post doesn't match authorized type" do
            setup do
              set(:post_type, "https://tent.example.org/types/fictitious/v0#")
            end

            behaves_as(:setup)
            behaves_as(:no_async_notification)
          end
        end
      end

      context "when authorized for explicit type and fragment" do
        setup do
          set(:read_types, %w( https://tent.io/types/status/v0# ))
        end

        context "when post is public" do
          setup do
            set(:public, true)
          end

          context "when post matches authorized type" do
            setup do
              set(:post_type, "https://tent.io/types/status/v0#")
            end

            behaves_as(:setup)
            behaves_as(:async_notification)
          end

          context "when post doesn't match authorized type" do
            setup do
              set(:post_type, "https://tent.io/types/status/v0#reply")
            end

            behaves_as(:setup)
            behaves_as(:no_async_notification)
          end
        end

        context "when post is private" do
          setup do
            set(:public, false)
          end

          context "when post matches authorized type" do
            setup do
              set(:post_type, "https://tent.io/types/status/v0#")
            end

            behaves_as(:setup)
            behaves_as(:async_notification)
          end

          context "when post doesn't match authorized type" do
            setup do
              set(:post_type, "https://tent.io/types/status/v0#reply")
            end

            behaves_as(:setup)
            behaves_as(:no_async_notification)
          end
        end
      end
    end
  end

  TentValidator.validators << AppValidator
end
