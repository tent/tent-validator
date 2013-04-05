require 'tent-validator/validators/post_validator'

module TentValidator
  module WithoutAuthentication

    class AppValidator < PostValidator
      def generate_app_post
        {
          :type => "https://tent.io/types/app/v0#",
          :content => {
            :name => "Example App Name",
            :description => "Example App Description",
            :url => "http://someapp.example.com",
            :redirect_uri => "http://someapp.example.com/oauth/callback",
            :post_types => {
              :read => %w( https://tent.io/types/status/v0# ),
              :write => %w( https://tent.io/types/status/v0# )
            },
            :scopes => %w( import_posts )
          }
        }
      end

      describe "POST /posts" do
        context "without authentication" do

          context "when app registration post" do
            set(:post) { generate_app_post }
            set(:content_schema, :post_app)

            behaves_as(:new_post)

            expect_response(:headers => :tent, :status => 200, :schema => :post) do
              data = get(:post)

              expect_headers(:post)
              expect_properties(data)
              expect_schema(get(:content_schema), "/content")

              res = clients(:no_auth, :server => :remote).post.create(data)

              if Hash === res.body
                expect_properties(:version => { :id => generate_version_signature(res.body) })
              end

              res
            end
          end

        end
      end
    end

  end

  TentValidator.validators << WithoutAuthentication::AppValidator
end
