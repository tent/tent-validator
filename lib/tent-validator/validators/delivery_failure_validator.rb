module TentValidator
  class DeliveryFailureValidator < TentValidator::Spec
    require 'tent-validator/validators/support/post_generators'
    include Support::PostGenerators

    require 'tent-validator/validators/support/app_post_generators'
    include Support::AppPostGenerators

    require 'tent-validator/validators/support/app_importer'
    include Support::AppImporter

    require 'tent-validator/validators/support/relationship_importer'
    include Support::RelationshipImporter

    describe "Delivery Failure Post" do
      shared_example :delivery_failure do
        expect_response(:status => 200, :schema => :data) do
          user = get(:user)
          data = generate_status_post
          data[:type] = get(:type)

          data[:mentions] = [{ 'entity' => user.entity }]

          expected_data = TentD::Utils::Hash.deep_dup(data)
          expected_data.delete(:permissions)
          expect_properties(:post => expected_data)

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
              'Content-Type' => %r{\A#{Regexp.escape(TentD::API::POST_CONTENT_TYPE % "https://tent.io/types/delivery-failure/v0##{TentClient::TentType.new(data[:type]).to_s(:fragment => false)}")}}
            )
            expect_headers(
              'Authorization' => %r{\bid=['"]#{Regexp.escape(get(:app_credentials)[:id])}['"]}
            )

            expect_properties(:content => {
              :entity => user.entity
            })

            expect_properties(:content => {
              :reason => get(:failure_reason)
            })
          end.expect_response(:status => 200) {}

          clients(:app_auth).post.create(data)
        end
      end

      shared_example :silent_delivery_failure do
        expect_response(:status => 200, :schema => :data) do
          user = get(:user)
          data = generate_status_post
          data[:type] = get(:type)

          expected_data = TentD::Utils::Hash.deep_dup(data)
          expected_data.delete(:permissions)
          expect_properties(:post => expected_data)

          # Setup negative async request expectation for webhook
          webhook = get(:webhook)
          expect_async_request(
            :method => "PUT",
            :url => webhook.url,
            :negative_expectation => true
          ) do
            expect_schema(:post)
            expect_headers(
              'Content-Type' => %r{\brel=['"]#{Regexp.escape("https://tent.io/rels/notification")}['"]}
            )
            expect_headers(
              'Content-Type' => %r{\A#{Regexp.escape(TentD::API::POST_CONTENT_TYPE % "https://tent.io/types/delivery-failure/v0##{TentClient::TentType.new(data[:type]).to_s(:fragment => false)}")}}
            )
            expect_headers(
              'Authorization' => %r{\bid=['"]#{Regexp.escape(get(:app_credentials)[:id])}['"]}
            )
          end

          clients(:app_auth).post.create(data)
        end
      end

      shared_example :delivery_success do
        expect_response(:status => 200, :schema => :data) do
          user = get(:user)
          data = generate_status_post

          data[:mentions] = [{ 'entity' => user.entity }]

          expected_data = TentD::Utils::Hash.deep_dup(data)
          expected_data.delete(:permissions)
          expect_properties(:post => expected_data)

          # Setup negative async request expectation for webhook
          webhook = get(:webhook)
          expect_async_request(
            :method => "PUT",
            :url => webhook.url,
            :negative_expectation => true
          ) do
            expect_schema(:post)
            expect_headers(
              'Content-Type' => %r{\brel=['"]#{Regexp.escape("https://tent.io/rels/notification")}['"]}
            )
            expect_headers(
              'Content-Type' => %r{\A#{Regexp.escape(TentD::API::POST_CONTENT_TYPE % "https://tent.io/types/delivery-failure/v0##{TentClient::TentType.new(data[:type]).to_s(:fragment => false)}")}}
            )
            expect_headers(
              'Authorization' => %r{\bid=['"]#{Regexp.escape(get(:app_credentials)[:id])}['"]}
            )
          end

          # Setup async request expectation for notification
          expect_async_request(
            :method => "PUT",
            :url => %r{\A#{user.entity}}
          ) do
            expect_schema(:post)
            expect_headers(
              'Content-Type' => %r{\brel=['"]#{Regexp.escape("https://tent.io/rels/notification")}['"]}
            )
            expect_headers(
              'Content-Type' => %r{\A#{Regexp.escape(TentD::API::POST_CONTENT_TYPE % data[:type])}}
            )
          end.expect_response(:status => 200) {}

          clients(:app_auth).post.create(data)
        end
      end

      context "when relationship exists" do
        context "when entity unreachable" do
          setup do
            set(:type, "https://example.org/types/status-#{TentD::Utils.timestamp}/v#{rand(1000)}#")
            set(:notification_types, ["https://tent.io/types/delivery-failure/v0##{TentClient::TentType.new(get(:type)).to_s(:fragment => false)}"])
            set(:read_types, get(:notification_types))

            user = TentD::Model::User.generate
            set(:user, user)
            set(:entity, user.entity)
            set(:meta_post, user.meta_post.as_json)

            manipulate_local_requests(user.id) do |env, app|
              [503, {}, []]
            end

            set(:failure_reason, "unreachable")
          end

          include_import_relationship_examples
          include_import_app_examples

          behaves_as(:delivery_failure)
        end

        context "when delivery failure" do
          setup do
            set(:type, "https://example.org/types/status-#{TentD::Utils.timestamp}/v#{rand(1000)}#")
            set(:notification_types, ["https://tent.io/types/delivery-failure/v0##{TentClient::TentType.new(get(:type)).to_s(:fragment => false)}"])
            set(:read_types, get(:notification_types))

            user = TentD::Model::User.generate
            set(:user, user)
            set(:entity, user.entity)
            set(:meta_post, user.meta_post.as_json)

            manipulate_local_requests(user.id) do |env, app|
              if env['CONTENT_TYPE'].to_s =~ %r{#{Regexp.escape(get(:type))}.+rel=['"][^'"]+notification['"]}
                [404, {}, []]
              else
                app.call(env)
              end
            end

            set(:failure_reason, 'delivery_failed')
          end

          include_import_relationship_examples
          include_import_app_examples

          behaves_as(:delivery_failure)
        end

        context "when delivery failure and no mention (should not receive notification)" do
          setup do
            set(:type, "https://example.org/types/status-#{TentD::Utils.timestamp}/v#{rand(1000)}#")
            set(:notification_types, ["https://tent.io/types/delivery-failure/v0##{TentClient::TentType.new(get(:type)).to_s(:fragment => false)}"])
            set(:read_types, get(:notification_types))

            user = TentD::Model::User.generate
            set(:user, user)
            set(:entity, user.entity)
            set(:meta_post, user.meta_post.as_json)

            manipulate_local_requests(user.id) do |env, app|
              if env['CONTENT_TYPE'].to_s =~ %r{#{Regexp.escape(get(:type))}.+rel=['"][^'"]+notification['"]}
                [404, {}, []]
              else
                app.call(env)
              end
            end
          end

          include_import_subscription_examples
          include_import_relationship_examples
          include_import_app_examples

          behaves_as(:silent_delivery_failure)
        end

        context "when delivery success" do
          setup do
            set(:type, "https://example.org/types/status-#{TentD::Utils.timestamp}/v#{rand(1000)}#")
            set(:notification_types, ["https://tent.io/types/delivery-failure/v0##{TentClient::TentType.new(get(:type)).to_s(:fragment => false)}"])
            set(:read_types, get(:notification_types))

            user = TentD::Model::User.generate
            set(:user, user)
            set(:entity, user.entity)
            set(:meta_post, user.meta_post.as_json)

            manipulate_local_requests(user.id) do |env, app|
              if env['CONTENT_TYPE'].to_s =~ %r{\brel=['"][^'"]+notification['"]}
                [200, {}, []]
              else
                app.call(env)
              end
            end
          end

          include_import_relationship_examples
          include_import_app_examples

          behaves_as(:delivery_success)
        end
      end

      context "when no relationship" do
        context "when entity unreachable" do
          setup do
            set(:type, "https://example.org/types/status-#{TentD::Utils.timestamp}/v#{rand(1000)}#")
            set(:notification_types, ["https://tent.io/types/delivery-failure/v0##{TentClient::TentType.new(get(:type)).to_s(:fragment => false)}"])
            set(:read_types, get(:notification_types))

            user = TentD::Model::User.generate
            set(:user, user)

            manipulate_local_requests(user.id) do |env, app|
              [503, {}, []]
            end

            set(:failure_reason, "unreachable")
          end

          include_import_app_examples

          behaves_as(:delivery_failure)
        end

        context "when discovery failure" do
          context "when no meta post link" do
            setup do
              set(:type, "https://example.org/types/status-#{TentD::Utils.timestamp}/v#{rand(1000)}#")
              set(:notification_types, ["https://tent.io/types/delivery-failure/v0##{TentClient::TentType.new(get(:type)).to_s(:fragment => false)}"])
              set(:read_types, get(:notification_types))

              user = TentD::Model::User.generate
              set(:user, user)

              manipulate_local_requests(user.id, :url => user.entity) do
                [200, {}, []]
              end

              set(:failure_reason, 'discovery_failed')
            end

            include_import_app_examples

            behaves_as(:delivery_failure)
          end

          context "when meta post link dead" do
            setup do
              set(:type, "https://example.org/types/status-#{TentD::Utils.timestamp}/v#{rand(1000)}#")
              set(:notification_types, ["https://tent.io/types/delivery-failure/v0##{TentClient::TentType.new(get(:type)).to_s(:fragment => false)}"])
              set(:read_types, get(:notification_types))

              user = TentD::Model::User.generate
              set(:user, user)

              meta_post_url = "#{user.entity}/posts/#{URI.encode_www_form_component(user.entity)}/fictitious-id"
              discovery_link_header = %(<#{meta_post_url}; rel="https://tent.io/rels/meta-post">)

              manipulate_local_requests(user.id, :url => user.entity) do |env, app|
                [200, { "Link" => discovery_link_header }, []]
              end


              set(:failure_reason, 'discovery_failed')
            end

            include_import_app_examples

            behaves_as(:delivery_failure)
          end

          context "when meta post link doesn't return a valid meta post" do
            setup do
              set(:type, "https://example.org/types/status-#{TentD::Utils.timestamp}/v#{rand(1000)}#")
              set(:notification_types, ["https://tent.io/types/delivery-failure/v0##{TentClient::TentType.new(get(:type)).to_s(:fragment => false)}"])
              set(:read_types, get(:notification_types))

              user = TentD::Model::User.generate
              set(:user, user)

              meta_post_url = "#{user.entity}/posts/#{URI.encode_www_form_component(user.entity)}/#{user.meta_post.public_id}"

              manipulate_local_requests(user.id, :url => meta_post_url) do |env, app|
                [200, { "Content-Type" => %(application/vnd.tent.post.v0+json; type="https://tent.io/types/meta/v0#") }, []]
              end


              set(:failure_reason, 'discovery_failed')
            end

            include_import_app_examples

            behaves_as(:delivery_failure)
          end

          context "when meta post link returns meta post without servers" do
            setup do
              set(:type, "https://example.org/types/status-#{TentD::Utils.timestamp}/v#{rand(1000)}#")
              set(:notification_types, ["https://tent.io/types/delivery-failure/v0##{TentClient::TentType.new(get(:type)).to_s(:fragment => false)}"])
              set(:read_types, get(:notification_types))

              user = TentD::Model::User.generate
              set(:user, user)

              meta_post_url = "#{user.entity}/posts/#{URI.encode_www_form_component(user.entity)}/#{user.meta_post.public_id}"
              meta_post_data = TentD::Utils::Hash.deep_dup(user.meta_post.as_json)
              meta_post_data[:content]['servers'] = []

              manipulate_local_requests(user.id, :url => meta_post_url) do |env, app|
                headers = {
                  "Content-Type" => %(application/vnd.tent.post.v0+json; type="https://tent.io/types/meta/v0#")
                }

                [200, headers, [Yajl::Encoder.encode(:post => meta_post_data)]]
              end


              set(:failure_reason, 'discovery_failed')
            end

            include_import_app_examples

            behaves_as(:delivery_failure)
          end
        end

        context "when relationship init failure" do
          setup do
            set(:type, "https://example.org/types/status-#{TentD::Utils.timestamp}/v#{rand(1000)}#")
            set(:notification_types, ["https://tent.io/types/delivery-failure/v0##{TentClient::TentType.new(get(:type)).to_s(:fragment => false)}"])
            set(:read_types, get(:notification_types))

            user = TentD::Model::User.generate
            set(:user, user)

            manipulate_local_requests(user.id) do |env, app|
              status, headers, body = app.call(env)

              if headers['Link'].to_s =~ %r{credentials}
                [404, {}, []]
              else
                [status, headers, body]
              end
            end

            set(:failure_reason, 'relationship_failed')
          end

          include_import_app_examples

          behaves_as(:delivery_failure)
        end

        context "when delivery failure" do
          setup do
            set(:type, "https://example.org/types/status-#{TentD::Utils.timestamp}/v#{rand(1000)}#")
            set(:notification_types, ["https://tent.io/types/delivery-failure/v0##{TentClient::TentType.new(get(:type)).to_s(:fragment => false)}"])
            set(:read_types, get(:notification_types))

            user = TentD::Model::User.generate
            set(:user, user)

            manipulate_local_requests(user.id) do |env, app|
              if env['CONTENT_TYPE'].to_s =~ %r{#{Regexp.escape(get(:type))}.+rel=['"][^'"]+notification['"]}
                [404, {}, []]
              else
                app.call(env)
              end
            end

            set(:failure_reason, 'delivery_failed')
          end

          include_import_app_examples

          behaves_as(:delivery_failure)
        end

        context "when delivery success" do
          setup do
            set(:type, "https://example.org/types/status-#{TentD::Utils.timestamp}/v#{rand(1000)}#")
            set(:notification_types, ["https://tent.io/types/delivery-failure/v0##{TentClient::TentType.new(get(:type)).to_s(:fragment => false)}"])
            set(:read_types, get(:notification_types))

            user = TentD::Model::User.generate
            set(:user, user)
          end

          include_import_app_examples

          behaves_as(:delivery_success)
        end
      end
    end
  end

  TentValidator.validators << DeliveryFailureValidator
end
