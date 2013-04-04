require 'tent-validator/validators/support/tent_header_expectation'
require 'tent-validator/validators/support/post_header_expectation'
require 'tent-validator/validators/support/error_header_expectation'
require 'tent-validator/validators/support/tent_schemas'

module TentValidator
  module WithoutAuthentication

    class AppValidator < Validator
      def generate_app_post
        data = {
          :type => "https://tent.io/types/app/v0#",
          :content => {
            :name => "Example App Name",
            :description => "Example App Description",
            :url => "http://someapp.example.com",
            :icon => "http://someapp.example.com/icon.png",
            :redirect_uri => "http://someapp.example.com/oauth/callback",
            :post_types => {
              :read => %w( https://tent.io/types/status/v0# ),
              :write => %w( https://tent.io/types/status/v0# )
            },
            :scopes => %w( import_posts )
          }
        }
        set(:app_post, data)
      end

      def invalid_value(type, format = nil)
        case type
        when "array"
          Hash.new
        when "boolean"
          nil
        when "number", "integer"
          "123"
        when "null"
          true
        when "object"
          ["My parent should be an object!"]
        when "string"
          if format
            case format
            when 'uri'
              "I'm not a uri!"
            end
          else
            421
          end
        end
      end

      describe "POST /posts" do
        context "without authentication" do

          context "when app registration post", :before => :generate_app_post do
            set(:content_schema, :post_app)

            expect_response(:headers => :tent, :status => 200, :schema => :post) do
              data = get(:app_post)

              expect_headers(:post)
              expect_properties(data)
              expect_schema(get(:content_schema), "/content")

              res = clients(:no_auth, :server => :remote).post.create(data)

              if Hash === res.body
                expect_properties(:version => { :id => generate_version_signature(res.body) })
              end

              res
            end

            context "with invalid attributes" do
              context "when extra field in content" do
                expect_response(:headers => :error, :status => 400, :schema => :error) do
                  data = get(:app_post).dup
                  data[:content][:extra_member] = "I shouldn't be here!"
                  clients(:no_auth, :server => :remote).post.create(data)
                end
              end

              invalid_member_expectation = proc do |path, property|
                expect_response(:headers => :error, :status => 400, :schema => :error) do
                  data = generate_app_post.dup
                  pointer = JsonPointer.new(data, path, :symbolize_keys => true)
                  pointer.value = invalid_value(property['type'], property['format'])
                  clients(:no_auth, :server => :remote).post.create(data)
                end

                if property['type'] == 'object' && property['properties']
                  property['properties'].each_pair do |name, property|
                    invalid_member_expectation.call(path + "/#{name}", property)
                  end
                end

                if property['type'] == 'array' && property['items']
                  invalid_member_expectation.call(path + "/-", { 'type' => property['items']['type'], 'format' => property['items']['format'] })
                end
              end

              context "when content member is wrong type" do
                TentValidator::Schemas[get(:content_schema)]["properties"].each_pair do |name, property|
                  invalid_member_expectation.call("/content/#{name}", property)
                end
              end

              context "when content is wrong type" do
                expect_response(:headers => :error, :status => 400, :schema => :error) do
                  data = get(:app_post).dup
                  data[:content] = "I should be an object"
                  clients(:no_auth, :server => :remote).post.create(data)
                end

                expect_response(:headers => :error, :status => 400, :schema => :error) do
                  data = get(:app_post).dup
                  data[:content] = ["My parent should be an object!"]
                  clients(:no_auth, :server => :remote).post.create(data)
                end

                expect_response(:headers => :error, :status => 400, :schema => :error) do
                  data = get(:app_post).dup
                  data[:content] = nil
                  clients(:no_auth, :server => :remote).post.create(data)
                end

                expect_response(:headers => :error, :status => 400, :schema => :error) do
                  data = get(:app_post).dup
                  data[:content] = true
                  clients(:no_auth, :server => :remote).post.create(data)
                end
              end
            end

            context "without request body" do
              expect_response(:headers => :error, :status => 400, :schema => :error) do
                clients(:no_auth, :server => :remote).post.create(nil) do |request|
                  request.headers['Content-Type'] = TentD::API::CONTENT_TYPE % 'https://tent.io/types/app/v0#'
                end
              end
            end

            context "when request body is wrong type" do
              expect_response(:headers => :error, :status => 400, :schema => :error) do
                clients(:no_auth, :server => :remote).post.create("I should be an object") do |request|
                  request.headers['Content-Type'] = TentD::API::CONTENT_TYPE % 'https://tent.io/types/app/v0#'
                end
              end
            end

            context "with invalid content-type header" do
              data = generate_app_post
              expect_response(:headers => :error, :status => 415, :schema => :error) do
                clients(:no_auth, :server => :remote).post.create(data) do |request|
                  request.headers['Content-Type'] = 'application/json'
                end
              end
            end
          end

        end
      end
    end

  end

  TentValidator.validators << WithoutAuthentication::AppValidator
end
