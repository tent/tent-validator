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
            :notification_post_types => %w( https://tent.io/types/status/v0# ),
            :scopes => %w( import_posts )
          },
          :permissions => {
            :public => false
          }
        }
      end

      def generate_app_icon_attachment
        {
          :content_type => "image/png",
          :category => 'icon',
          :name => 'appicon.png',
          :data => "Fake image data"
        }
      end

      describe "POST /posts" do
        context "without authentication" do

          context "when app registration post" do
            set(:post) { generate_app_post }
            set(:content_schema, :post_app)

            behaves_as(:new_post)

            context "with icon attachment" do
              set(:post_attachments) { [generate_app_icon_attachment] }

              behaves_as(:new_post)
            end
          end

        end
      end
    end

  end

  TentValidator.validators << WithoutAuthentication::AppValidator
end
