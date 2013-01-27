require 'faker'

module TentValidator
  class AppJSONGenerator < JSONGenerator
    register :app

    def simple
      {
        :name => Faker::Name.name,
        :description => Faker::Lorem.paragraph,
        :url => Faker::Internet.url,
        :icon => Faker::Internet.url,
        :redirect_uris => [Faker::Internet.url, Faker::Internet.url],
        :scopes => {
          :write_profile => Faker::Lorem.paragraph,
          :read_followings => Faker::Lorem.paragraph
        }
      }
    end

    def with_auth
      simple.merge(
        :id => random_id,
        :mac_key_id => 'a:' + random_id,
        :mac_algorithm => 'hmac-sha-256',
        :mac_key => SecureRandom.hex(16)
      )
    end
  end
end
