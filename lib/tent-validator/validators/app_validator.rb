module TentValidator
  class AppValidator < TentValidator::Spec
    require 'tent-validator/validators/support/post_generators'
    include Support::PostGenerators

    require 'tent-validator/validators/support/app_post_generators'
    include Support::AppPostGenerators

    require 'tent-validator/validators/support/app_importer'
    include Support::AppImporter

    describe "App update with app credentials" do
      include_import_app_examples

      expect_response(:status => 200, :schema => :data) do
        client = clients(:custom, { :id => get(:app_credentials)[:id] }.merge(get(:app_credentials)[:content]))

        attrs = TentD::Utils::Hash.deep_dup(get(:app))
        attrs[:version] = {
          :parents => [{
            :version => attrs[:version][:id]
          }]
        }

        client.post.update(attrs[:entity], attrs[:id], attrs)
      end
    end

    describe "App notifications" do
      # create app on remote server with generated webhook url (via import)
      # create post for which app is registered to be notified about
      # set async expectation that app receives post notification to webhook url

      shared_example :setup do
        include_import_app_examples
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
            set(:notification_types, [get(:post_type)])
          end

          behaves_as(:setup)
          behaves_as(:async_notification)
        end

        context "when post is private" do
          setup do
            set(:public, false)
            set(:post_type, "https://tent.io/types/status/v0#")
            set(:notification_types, [get(:post_type)])
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
              set(:notification_types, [get(:post_type)])
            end

            behaves_as(:setup)
            behaves_as(:async_notification)
          end

          context "when post doesn't match authorized type" do
            setup do
              set(:post_type, "https://tent.example.org/types/fictitious/v0#")
              set(:notification_types, [get(:post_type)])
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
              set(:notification_types, [get(:post_type)])
            end

            behaves_as(:setup)
            behaves_as(:async_notification)
          end

          context "when post doesn't match authorized type" do
            setup do
              set(:post_type, "https://tent.example.org/types/fictitious/v0#")
              set(:notification_types, [get(:post_type)])
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
              set(:notification_types, [get(:post_type)])
            end

            behaves_as(:setup)
            behaves_as(:async_notification)
          end

          context "when post doesn't match authorized type" do
            setup do
              set(:post_type, "https://tent.io/types/status/v0#reply")
              set(:notification_types, [get(:post_type)])
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
              set(:notification_types, [get(:post_type)])
            end

            behaves_as(:setup)
            behaves_as(:async_notification)
          end

          context "when post doesn't match authorized type" do
            setup do
              set(:post_type, "https://tent.io/types/status/v0#reply")
              set(:notification_types, [get(:post_type)])
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
