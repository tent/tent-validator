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

      describe "PUT /followings/:id (when authorized via identity)"

      describe "PUT /followings/:id (when authorized via scope)"

      describe "PUT /followings/:id (when authorized via scope and does not exist)"

      describe "PUT /followings/:id (when unauthorized)"

      describe "GET /followings/:id (when authorized via identity)"

      describe "GET /followings/:id (when authorized via scope)"

      describe "GET /followings/:id (when unauthorized)"

      describe "GET /followings/:entity (when authorized via identity)"

      describe "GET /followings/:entity (when authorized via scope)"

      describe "GET /followings/:entity (when unauthorized)"

      describe "GET /followings/:id/* (when authorized)"

      describe "GET /followings/:id/* (when unauthorized)"

      describe "GET /followings (when authorized)"

      describe "GET /followings (when unauthorized)"

      describe "HEAD /followings (when authorized)"

      describe "HEAD /followings (when unauthorized)"

      describe "DELETE /followings/:id (when authorized via identity)"

      describe "DELETE /followings/:id (when authorized via scope)"

      describe "DELETE /followings/:id (when unauthorized)"
    end
  end
end
