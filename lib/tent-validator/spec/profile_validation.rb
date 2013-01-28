require 'tentd/core_ext/hash/slice'

module TentValidator
  module Spec
    class ProfileValidation < Validation
      describe "OPTIONS /profile" do
        expect_response :tent_cors, :status => 200 do
          clients(:app, :server => :remote).http.options("profile")
        end
      end

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

        # Create authorized authorization
        authorization = JSONGenerator.generate(:app_authorization, :with_auth, :scopes => %w[ read_profile write_profile ], :profile_info_types => %w[ all ])
        set(:authorized_app_authorization, authorization)
        expect_response(:tent, :schema => :app_authorization, :status => 200) do
          clients(:app, :server => :remote).app.authorization.create(app[:id], authorization)
        end.after do |result|
          if result.response.success?
          end
        end

        # Create unauthorized authorization
        authorization2 = JSONGenerator.generate(:app_authorization, :with_auth, :scopes => %w[ read_profile write_profile ], :profile_info_types => %w[])
        set(:unauthorized_app_authorization, authorization2)
        expect_response(:tent, :schema => :app_authorization, :status => 200) do
          clients(:app, :server => :remote).app.authorization.create(app[:id], authorization2)
        end
      end
    end
  end
end
