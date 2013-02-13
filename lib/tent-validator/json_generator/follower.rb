require 'faker'

module TentValidator
  class FollowerJSONGenerator < JSONGenerator
    register :follower

    def simple(options ={})
      {
        :entity => Faker::Internet.url,
        :notification_path => "/abc"
      }.merge(options)
    end

    def with_auth(options = {})
      simple.merge(
        :id => random_id,
        :mac_key_id => 'a:' + random_id,
        :mac_algorithm => 'hmac-sha-256',
        :mac_key => SecureRandom.hex(16),
        :created_at => Time.now.to_i - 1000,
        :permissions => {
          :public => false
        },
        :types => %w[ https://tent.io/types/post/status/v0.1.0 ],
        :licenses => [Faker::Internet.url, Faker::Internet.url]
      ).merge(options)
    end
  end
end
