require 'tentd/core_ext/hash/slice'

module TentValidator
  module Spec
    class ProfileValidation < Validation
      describe "OPTIONS /profile" do
        expect_response :tent_cors, :status => 200 do
          clients(:app, :server => :remote).http.options("profile")
        end
      end

      describe "OPTIONS /profile/:type" do
        expect_response :tent_cors, :status => 200 do
          clients(:app, :server => :remote).http.options("profile/#{URI.encode_www_form_component('https://tent.io/types/info/core/v0.1.0')}")
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

        # Create fully authorized authorization
        authorization = JSONGenerator.generate(:app_authorization, :with_auth, :scopes => %w[ read_profile write_profile ], :profile_info_types => %w[ all ])
        set(:full_authorization, authorization)
        set(:full_authorization_details, authorization.slice(:mac_key_id, :mac_key, :mac_algorithm))
        expect_response(:tent, :schema => :app_authorization, :status => 200) do
          clients(:app, :server => :remote).app.authorization.create(app[:id], authorization)
        end

        # Create explicitly authorized authorization
        set(:explicit_authorization_type, 'https://example.org/types/info/example/v0.1.0')
        authorization2 = JSONGenerator.generate(:app_authorization, :with_auth, :scopes => %w[ read_profile write_profile ], :profile_info_types => [get(:explicit_authorization_type)])
        set(:explicit_authorization, authorization2)
        set(:explicit_authorization_details, authorization2.slice(:mac_key_id, :mac_key, :mac_algorithm))
        expect_response(:tent, :schema => :app_authorization, :status => 200) do
          clients(:app, :server => :remote).app.authorization.create(app[:id], authorization2)
        end

        # Create fully unauthorized authorization
        authorization3 = JSONGenerator.generate(:app_authorization, :with_auth, :scopes => %w[ read_profile write_profile ], :profile_info_types => %w[])
        set(:explicit_unauthorization, authorization3)
        set(:explicit_unauthorization_details, authorization3.slice(:mac_key_id, :mac_key, :mac_algorithm))
        expect_response(:tent, :schema => :app_authorization, :status => 200) do
          clients(:app, :server => :remote).app.authorization.create(app[:id], authorization3)
        end
      end

      describe "PUT /profile/:type (when fully authorized and :type exists)", :depends_on => create_authorizations
        # TODO: update basic profile (ensure public)

      create_type = describe "PUT /profile/:type (when fully authorized and :type does not exist)", :depends_on => create_authorizations
        # TODO: create new private profile section (ensure this gets deleted in a DELETE validation)

      describe "PUT /profile/:type (when explicitly authorized and :type exists)", :depends_on => create_authorizations
        # TODO: update core profile

      create_another_type = describe "PUT /profile/:type (when explicitly authorized and :type does not exist)", :depends_on => create_authorizations
        # TODO: create another type for which authorization has explicit permission

      describe "PUT /profile/:type (when unauthorized and :type exists)", :depends_on => create_authorizations
        # TODO: attempt to update core profile with restricted authorization

      describe "PUT /profile/:type (when unauthorized and :type does not exist)", :depends_on => create_authorizations
        # TODO: attempt to update bogus section with restricted authorization

      describe "GET /profile (public)", :depends_on => create_authorizations
        # TODO: validate presence of core profile type

      describe "GET /profile (private when fully authorized)", :depends_on => create_type
        # TODO: validate presence of private section created in a PUT validation

      describe "GET /profile (private when explicitly authorized)", :depends_on => create_another_type
        # TODO: validate presence of private section created in another PUT validation

      describe "GET /profile/:type (public and exists)", :depends_on => create_authorizations
        # TODO: validate presence of basic profile type

      describe "GET /profile/:type (does not exist when no authorization)", :depends_on => create_authorizations
        # TODO: lookup bogus type

      describe "GET /profile/:type (private and exists when fully authorized)", :depends_on => create_type
        # TODO: lookup private section created in a PUT validation

      describe "GET /profile/:type (does not exist when fully authorized)", :depends_on => create_authorizations
        # TODO: lookup bogus type

      describe "GET /profile/:type (private and exists when explicitly authorized)", :depends_on => create_type
        # TODO: lookup private section created in a PUT validation

      describe "GET /profile/:type (does not exist when explicitly authorized)", :depends_on => create_authorizations
        # TODO: lookup bogus type for which authorization has explicit access to

      describe "GET /profile/:type (private and exists when unauthorized)", :depends_on => create_type
        # TODO: lookup private section created in a PUT validation

      describe "DELETE /profile/:type (when fully authorized and :type exists)", :depends_on => create_type
        # TODO: delete type created in a PUT validation

      describe "DELETE /profile/:type (when fully authorized and :type does not exist)", :depends_on => create_authorizations
        # TODO: attempt to deleted bogus type

      describe "DELETE /profile/:type (when explicitly authorized and :type exists)", :depends_on => create_another_type
        # TODO: delete type created in another PUT validation

      describe "DELETE /profile/:type (when explicitly authorized and :type does not exist)", :depends_on => create_authorizations
        # TODO: attempt to delete a bugus type for which authorization has explicit permission

      describe "DELETE /profile/:type (when unauthorized and :type exists)", :depends_on => create_authorizations
        # TODO: attempt to delete core profile

      describe "DELETE /profile/:type (when unauthorized and :type does not exist)", :depends_on => create_authorizations
        # TODO: attempt to delete bogus profile section
    end
  end
end
