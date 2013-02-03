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

      # Load newly created columns
      User.send(:set_columns, User.db[:users].naked.columns)
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

      def app_authorization
        @app_authorization ||= find_or_create_app_authorization
      end

      def find_or_create_app_authorization
        name = "Local Validator"
        if (app = apps_dataset.where(:name => name).first) && (auth = app.authorizations.first)
          return auth
        end

        # Create app and authorization with full access
        app = App.create(TentValidator::JSONGenerator.generate(:app, :simple, :scopes => {}, :name => name, :user_id => id))
        AppAuthorization.create(TentValidator::JSONGenerator.generate(:app_authorization, :simple, :scopes => %w[ read_posts write_posts import_posts read_profile write_profile read_followers write_followers read_followings write_followings read_groups write_groups read_permissions write_permissions read_apps write_apps read_secrets write_secrets ], :post_types => %w[ all ], :profile_info_types => %w[ all ], :app_id => app.id))
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

      def profile
        _user = User.current
        User.current = self
        profile = ProfileInfo.get_profile
        User.current = _user
        profile
      end
    end
  end
end
