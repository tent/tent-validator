require 'faker'

module TentValidator
  class AppAuthorizationJSONGenerator < JSONGenerator
    register :app_authorization

    def simple
      {
        :scopes => %w[ read_posts write_posts ],
        :profile_info_types => %w[ https://tent.io/types/info/basic/v0.1.0 ],
        :post_types => %w[ https://tent.io/types/post/status/v0.1.0 ],
        :notification_url => ENV['VALIDATOR_NOTIFICATION_URL']
      }
    end

    def with_auth
      simple.merge(
        :id => random_id,
        :mac_key_id => 'u:' + random_id,
        :mac_algorithm => 'hmac-sha-256',
        :mac_key => SecureRandom.hex(16)
      )
    end
  end
end
