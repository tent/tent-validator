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
        authorization = JSONGenerator.generate(:app_authorization, :with_auth, :scopes => %w[ read_followings write_followings read_groups ])
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

      describe "OPTIONS /followings" do
        expect_response :tent_cors, :status => 200 do
          clients(:no_auth, :server => :remote).http.options("followings")
        end
      end

      describe "OPTIONS /followings/(:id|:entity)" do
        expect_response :tent_cors, :status => 200 do
          clients(:no_auth, :server => :remote).http.options("followings/abc")
        end
      end

      describe "OPTIONS /followings/:id/*" do
        expect_response :tent_cors, :status => 200 do
          clients(:no_auth, :server => :remote).http.options("followings/abc/cde")
        end
      end

      follow = describe "POST /followings (when authorized)", :depends_on => create_authorizations do
        auth_details = get(:full_authorization_details)
        user = TentD::Model::User.generate
        set(:user_id, user.id)
        expect_response(:tent, :schema => :following, :status => 200, :properties => { :entity => user.entity }) do
          clients(:custom, auth_details.merge(:server => :remote)).following.create(user.entity)
        end.after do |result|
          if result.response.success?
            set(:following, result.response.body)
          end
        end

        expect_response(:tent, :schema => :follow, :status => 200) do
          clients(:app, :server => :local, :user => user.id).follower.get(get(:following)["remote_id"])
        end
      end

      describe "POST /followings (when authorized and already following)", :depends_on => follow do
        auth_details = get(:full_authorization_details)
        user = TentD::Model::User.first(:id => get(:user_id))
        expect_response(:tent, :schema => :error, :status => 409) do
          clients(:custom, auth_details.merge(:server => :remote)).following.create(user.entity)
        end
      end

      describe "POST /followings (when unauthorized)", :depends_on => create_authorizations do
        auth_details = get(:explicit_unauthorization_details)
        user = TentD::Model::User.generate
        expect_response(:tent, :schema => :error, :status => 403) do
          clients(:custom, auth_details.merge(:server => :remote)).following.create(user.entity)
        end
      end

      describe "PUT /followings/:id (when authorized and has read_groups scope)", :depends_on => follow do
        auth_details = get(:full_authorization_details)
        following = get(:following) || {}
        data = { "permissions" => { "public" => false }, "groups" => [get(:group)] }
        expected_data = data.dup
        expected_data["groups"] = [get(:group).slice("id")]
        expect_response(:tent, :schema => :following, :status => 200, :properties => expected_data) do
          clients(:custom, auth_details.merge(:server => :remote)).following.update(following['id'], data)
        end
      end

      describe "PUT /followings/:id (when authorized)", :depends_on => follow

      describe "PUT /followings/:id (when authorized and does not exist)", :depends_on => follow do
        auth_details = get(:full_authorization_details)
        data = { "permissions" => { "public" => false }, "groups" => [get(:group)] }
        expect_response(:tent, :schema => :error, :status => 404) do
          clients(:custom, auth_details.merge(:server => :remote)).following.update('bugus-id', data)
        end
      end

      describe "PUT /followings/:id (when unauthorized)", :depends_on => follow do
        auth_details = get(:explicit_unauthorization_details)
        following = get(:following) || {}
        data = { "permissions" => { "public" => false }, "groups" => [get(:group)] }
        expect_response(:tent, :schema => :error, :status => 403) do
          clients(:custom, auth_details.merge(:server => :remote)).following.update(following['id'], data)
        end
      end

      describe "GET /followings/:id (when authorized and has read_groups scope)"

      describe "GET /followings/:id (when authorized and has read_secrets scope)"

      describe "GET /followings/:id (when authorized)"

      describe "GET /followings/:id (when unauthorized)"

      describe "GET /followings/:entity (when authorized and has read_groups scope)"

      describe "GET /followings/:entity (when authorized and has read_secrets scope)"

      describe "GET /followings/:entity (when authorized)"

      describe "GET /followings/:entity (when unauthorized)"

      describe "GET /followings/:id/* (when authorized)"

      describe "GET /followings/:id/* (when unauthorized)"

      describe "GET /followings (when authorized and has read_groups scope)"

      describe "GET /followings (when authorized and has read_secrets scope)"

      describe "GET /followings (when authorized)"

      describe "GET /followings (when unauthorized)"

      describe "HEAD /followings (when authorized)"

      describe "HEAD /followings (when unauthorized)"

      describe "DELETE /followings/:id (when unauthorized)", :depends_on => follow do
        auth_details = get(:explicit_unauthorization_details)
        following = get(:following) || {}
        expect_response(:tent, :schema => :error, :status => 403) do
          clients(:custom, auth_details.merge(:server => :remote)).following.delete(following['id'])
        end

        expect_response(:tent, :schema => :follow, :status => 200) do
          clients(:app, :server => :local, :user => get(:user_id)).follower.get(get(:following)["remote_id"])
        end
      end

      describe "DELETE /followings/:id (when authorized)", :depends_on => follow do
        auth_details = get(:full_authorization_details)
        following = get(:following) || {}
        expect_response(:status => 200) do
          clients(:custom, auth_details.merge(:server => :remote)).following.delete(following['id'])
        end

        expect_response(:tent, :schema => :error, :status => 404) do
          clients(:app, :server => :local, :user => get(:user_id)).follower.get(get(:following)["remote_id"])
        end
      end
    end
  end
end
