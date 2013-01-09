require 'sequel'
require 'sequel-pg_array'
require 'sequel-json'
require 'hashie'

module TentValidator
  class App
    DB = Sequel.connect(ENV['VALIDATOR_DATABASE_URL'])

    class User < Sequel::Model(DB[:users])
      unless DB.table_exists?(:users)
        DB.create_table :users do
          primary_key :id
          column :entity, "text"
          column :app_id, "text"
          column :app_mac, "text", :default => "{}"
          column :profile, "text", :default => "{}"
          column :mac_key_id, "text"
          column :mac_key, "text"
          column :mac_algorithm, "text"
          column :profile_info_types, "text[]", :default=>"{}"
          column :post_types, "text[]", :default=>"{}"
        end
        User.columns # load columns
      end

      plugin :serialization
      serialize_attributes :pg_array, :profile_info_types, :post_types
      serialize_attributes :json, :app_mac, :profile

      def self.find_or_create_from_auth_hash(auth_hash)
        user = first(:entity => auth_hash.uid)

        app = auth_hash.extra.raw_info.app
        app_auth = auth_hash.extra.raw_info.app_authorization
        credentials = auth_hash.extra.credentials
        attributes = {
          :entity => auth_hash.uid,
          :app_id => app.id,
          :app_mac => {
            'mac_key_id' => app.mac_key_id,
            'mac_key' => app.mac_key,
            'mac_algorithm' => app.mac_algorithm
          },
          :profile => auth_hash.extra.raw_info.profile,
          :mac_key_id => app_auth.access_token,
          :mac_key => app_auth.mac_key,
          :mac_algorithm => app_auth.mac_algorithm,
          :profile_info_types => app_auth.profile_info_types,
          :post_types => app_auth.post_types
        }

        if user
          user.update(attributes)
          user
        else
          create(attributes)
        end
      end

      def self.app_created_for_entity(app, entity)
        return unless user = first(:entity => entity)
        user.destroy
      end

      def self.get_app_from_entity(entity)
        return unless user = first(:entity => entity)
        Hashie::Mash.new(
          :id => user.app_id,
          :mac_key_id => user.app_mac['mac_key_id'],
          :mac_key => user.app_mac['mac_key'],
          :mac_algorithm => user.app_mac['mac_algorithm']
        )
      end

      def primary_server
        (core_profile['servers'] || []).first
      end

      def auth_details
        {
          :mac_key_id => mac_key_id,
          :mac_key => mac_key,
          :mac_algorithm => mac_algorithm
        }
      end

      def basic_profile
        (profile || {})['https://tent.io/types/info/basic/v0.1.0'] || {}
      end

      def core_profile
        (profile || {})['https://tent.io/types/info/core/v0.1.0'] || {}
      end
    end
  end
end
