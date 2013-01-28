require 'tentd/core_ext/hash/slice'

module TentValidator
  module Spec
    class GroupsValidation < Validation
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
        authorization = JSONGenerator.generate(:app_authorization, :with_auth, :scopes => %w[ read_groups write_groups ])
        set(:authorized_app_authorization, authorization)
        expect_response(:tent, :schema => :app_authorization, :status => 200) do
          clients(:app, :server => :remote).app.authorization.create(app[:id], authorization)
        end.after do |result|
          if result.response.success?
          end
        end

        # Create unauthorized authorization
        authorization2 = JSONGenerator.generate(:app_authorization, :with_auth, :scopes => %w[ read_posts write_posts ])
        set(:unauthorized_app_authorization, authorization2)
        expect_response(:tent, :schema => :app_authorization, :status => 200) do
          clients(:app, :server => :remote).app.authorization.create(app[:id], authorization2)
        end
      end
    end
  end
end
