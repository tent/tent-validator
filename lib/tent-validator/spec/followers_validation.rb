require 'tentd/core_ext/hash/slice'
require 'faker'

module TentValidator
  module Spec
    class FollowersValidation < Validation
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

        # Create fully authorized authorization (with read_groups)
        authorization = JSONGenerator.generate(:app_authorization, :with_auth, :scopes => %w[ read_followers write_followers read_groups ])
        set(:full_authorization_with_groups, authorization)
        set(:full_authorization_with_groups_details, authorization.slice(:mac_key_id, :mac_key, :mac_algorithm))
        expect_response(:tent, :schema => :app_authorization, :status => 200) do
          clients(:app, :server => :remote).app.authorization.create(app[:id], authorization)
        end

        # Create fully authorized authorization (without read_groups)
        authorization2 = JSONGenerator.generate(:app_authorization, :with_auth, :scopes => %w[ read_followers write_followers ])
        set(:full_authorization, authorization2)
        set(:full_authorization_details, authorization2.slice(:mac_key_id, :mac_key, :mac_algorithm))
        expect_response(:tent, :schema => :app_authorization, :status => 200) do
          clients(:app, :server => :remote).app.authorization.create(app[:id], authorization2)
        end

        # Create fully unauthorized authorization
        authorization3 = JSONGenerator.generate(:app_authorization, :with_auth, :scopes => %w[ read_followings write_followings ])
        set(:explicit_unauthorization, authorization3)
        set(:explicit_unauthorization_details, authorization3.slice(:mac_key_id, :mac_key, :mac_algorithm))
        expect_response(:tent, :schema => :app_authorization, :status => 200) do
          clients(:app, :server => :remote).app.authorization.create(app[:id], authorization3)
        end

        # Create group
        group_data = JSONGenerator.generate(:group, :simple)
        expect_response(:tent, :schema => :group, :status => 200, :properties => group_data) do
          clients(:app, :server => :remote).group.create(group_data)
        end.after do |result|
          if result.response.success?
            set(:group, result.response.body)
          end
        end
      end

      describe "OPTIONS /followers" do
        expect_response :tent_cors, :status => 200 do
          clients(:no_auth, :server => :remote).http.options("followers")
        end
      end

      describe "OPTIONS /followers/(:id|:entity)" do
        expect_response :tent_cors, :status => 200 do
          clients(:no_auth, :server => :remote).http.options("followers/abc")
        end
      end

    end
  end
end
