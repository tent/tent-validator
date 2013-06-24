module TentValidator
  module Support
    module AppPostGenerators
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
            :scopes => %w( permissions )
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

      def generate_app_auth_post
        {
          :type => "https://tent.io/types/app-auth/v0#",
          :content => {
            :post_types => {
              :read => %w( all ),
              :write => %w( all )
            },
            :scopes => %w( permissions )
          },
          :permissions => {
            :public => false
          }
        }
      end
    end
  end
end
