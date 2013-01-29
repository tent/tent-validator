require 'tentd/core_ext/hash/slice'

module TentValidator
  module Spec
    class FollowingsValidation < Validation
      create_authorizations = describe "Create authorizations" do
        # Create app
        app = JSONGenerator.generate(:app, :with_auth)
        expect_response(:tent, :schema => :app, :status => 200, :properties => app) do
          clients(:app, :server => :remote).app.create(app)
        end.after do |result|
          if result.response.success?
            set(:app, app)
          end
        end

        # Create fully authorized authorization
        authorization = JSONGenerator.generate(:app_authorization, :with_auth, :scopes => %w[ read_followings write_followings ])
        set(:full_authorization, authorization)
        set(:full_authorization_details, authorization.slice(:mac_key_id, :mac_key, :mac_algorithm))
        expect_response(:tent, :schema => :app_authorization, :status => 200) do
          clients(:app, :server => :remote).app.authorization.create(app[:id], authorization)
        end

        # Create fully unauthorized authorization
        authorization3 = JSONGenerator.generate(:app_authorization, :with_auth, :scopes => %w[ read_followers write_followers ])
        set(:explicit_unauthorization, authorization3)
        set(:explicit_unauthorization_details, authorization3.slice(:mac_key_id, :mac_key, :mac_algorithm))
        expect_response(:tent, :schema => :app_authorization, :status => 200) do
          clients(:app, :server => :remote).app.authorization.create(app[:id], authorization3)
        end
      end
    end
  end
end
