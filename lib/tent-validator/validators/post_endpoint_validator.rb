module TentValidator
  class PostEndpointValidator < TentValidator::Spec

    require 'tent-validator/validators/support/post_generators'
    class << self
      include Support::PostGenerators
    end
    include Support::PostGenerators

    require 'tent-validator/validators/support/app_post_generators'
    include Support::AppPostGenerators

    require 'tent-validator/validators/support/oauth'
    include Support::OAuth

    create_post = lambda do |opts|
      data = generate_status_post(opts[:public])
      res = clients(:app).post.create(data)

      res_validation = ApiValidator::Json.new(data).validate(res)
      raise SetupFailure.new("Failed to create post with attachments! #{res.status}\n\t#{Yajl::Encoder.encode(res_validation[:diff])}\n\t#{res.body}") unless res_validation[:valid]

      TentD::Utils::Hash.symbolize_keys(res.body)
    end

    create_post_version = lambda do |post, client|
      data = generate_status_post(post[:permissions][:public])
      data[:version] = { :parents => [{:version => post[:version][:id] }] }

      set(:post_version, data)

      client.post.update(post[:entity], post[:id], data)
    end

    context "when public post" do
      setup do
        set(:post, create_post.call(:public => true))
      end

      describe "PUT new post version" do
        context "without auth" do
          expect_response(:status => 403) do
            create_post_version.call(get(:post), clients(:no_auth))
          end
        end

        context "with auth" do
          context "when unauthorized" do
            authenticate_with_permissions(:write_post_types => [])

            expect_response(:status => 403) do
              create_post_version.call(get(:post), get(:client))
            end
          end

          context "when limited authorization" do
            setup do
              authenticate_with_permissions(:write_post_types => [get(:post)[:type]])
            end

            context '' do # workaround to ensure `expect_response`s in `setup` are called first
              expect_response(:status => 200, :schema => :post) do
                res = create_post_version.call(get(:post), get(:client))

                expect_properties(get(:post_version).merge(:id => get(:post)[:id]))

                res
              end
            end
          end

          context "when full authorization" do
            setup do
              set(:client, clients(:app))
            end

            expect_response(:status => 200, :schema => :post) do
              res = create_post_version.call(get(:post), get(:client))

              expect_properties(get(:post_version).merge(:id => get(:post)[:id]))

              res
            end
          end
        end
      end
    end

  end

  TentValidator.validators << PostEndpointValidator
end
