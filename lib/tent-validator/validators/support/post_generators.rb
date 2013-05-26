module TentValidator
  module Support
    module PostGenerators

      def generate_status_post(is_public=true)
        {
          :type => "https://tent.io/types/status/v0#",
          :content => {
            :text => "The quick brown fox jumps over the lazy dog."
          },
          :permissions => {
            :public => is_public
          }
        }
      end

      def generate_status_reply_post(is_public=true)
        post = generate_status_post(is_public)
        post[:type] << "reply"
        post
      end

      def generate_random_post(is_public=true)
        {
          :type => "https://tent.io/types/fictitious/v0#",
          :content => {
            :description => "chunky tempeh bacon!"
          },
          :permissions => {
            :public => is_public
          }
        }
      end

    end
  end
end
