require 'faker'

module TentValidator
  module Support
    module PostGenerators

      def generate_status_post(is_public=true)
        {
          :type => "https://tent.io/types/status/v0#",
          :content => {
            :text => Faker::Lorem.sentences(4).join(' ').slice(0, 256)
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

      def generate_fictitious_post(is_public=true)
        {
          :type => "https://tent.io/types/fictitious/v0#",
          :content => {
            :description => Faker::Lorem.sentence
          },
          :permissions => {
            :public => is_public
          }
        }
      end

      def generate_attachment
        {
          :content_type => "image/png",
          :category => Faker::Lorem.word,
          :name => "#{Faker::Lorem.words(2).join('-')}.png",
          :data => Faker::Lorem.words(50).join(' ')
        }
      end

    end
  end
end
