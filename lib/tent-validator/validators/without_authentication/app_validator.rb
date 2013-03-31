require 'tent-validator/validators/support/tent_header_expectation'
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

      describe "POST /posts" do
        context "without authentication" do
          context "when app registration post", :before => :generate_app_post do
            expect_response(:headers => :tent, :status => 200, :schema => :post) do
              data = get(:app_post)

              expect_properties(data)
              expect_schema(:post_app, "/content")

              clients(:no_auth, :server => :remote).post.create(data)
            end
          end
        end
      end
    end

  end

  TentValidator.validators << WithoutAuthentication::AppValidator
end
