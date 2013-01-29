# Setup tentd
TentValidator.tentd

module TentD
  module Model
    # Automigrate added fields
    unless ([:entity, :public_id] - User.columns).empty?
      User.db.alter_table(:users) do
        add_column :entity, 'text'
        add_column :public_id, 'text'
      end
    end

    # reopening class defined in tentd/model/user.rb
    class User
      ValidatorHostNotSetError = Class.new(StandardError)

      class << self
        include TentD::Model::RandomPublicId
      end

      def self.generate
        db.transaction do
          public_id = random_id
          user = create(:public_id => public_id, :entity => entity_from_public_id(public_id))
          user.create_core_profile
          user
        end
      end

      def self.entity_from_public_id(public_id)
        permanent_url("/#{public_id}/tent")
      end

      def self.permanent_url(path='')
        raise ValidatorHostNotSetError.new('You need to set the VALIDATOR_HOST environment variable!') unless ENV['VALIDATOR_HOST']
        ENV['VALIDATOR_HOST'] + path
      end

      def self.create_authorization(attributes)
        # TODO: create app and authorization
      end

      def create_core_profile
        ProfileInfo.create(
          :user_id => id,
          :type => TentD::Model::ProfileInfo::TENT_PROFILE_TYPE_URI,
          :content => {
            :entity => entity,
            :licenses => [],
            :servers => [entity]
          },
          :public => true
        )
      end
    end
  end
end
