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
        # Shared vars
        set(:basic_profile_type_uri, 'https://tent.io/types/info/basic/v0.1.0')
        set(:core_profile_type_uri, 'https://tent.io/types/info/core/v0.1.0')
        set(:example_profile_type_uri, 'https://example.org/types/info/example/v0.1.0')
        set(:other_profile_type_uri, 'https://example.com/types/info/other/v0.1.0')
        set(:bogus_profile_type_uri, 'https://example.com/types/info/bogus/v0.1.0')

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
        authorization2 = JSONGenerator.generate(:app_authorization, :with_auth, :scopes => %w[ read_profile write_profile ], :profile_info_types => [get(:example_profile_type_uri)])
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

      describe "PUT /profile/:type (when fully authorized and :type exists)", :depends_on => create_authorizations do
        auth_details = get(:full_authorization_details)
        data = JSONGenerator.generate(:profile, :basic)
        type = get(:basic_profile_type_uri)
        expect_response(:tent, :schema => :profile, :status => 200, :properties => { type => data.merge(:version => /\A\d+\Z/) }) do
          clients(:custom, auth_details.merge(:server => :remote)).profile.update(type, data)
        end
      end

      create_type = describe "PUT /profile/:type (when fully authorized and :type does not exist)", :depends_on => create_authorizations do
        auth_details = get(:full_authorization_details)
        data = JSONGenerator.generate(:profile, :other)
        type = get(:other_profile_type_uri)
        expect_response(:tent, :schema => :profile, :status => 200, :properties => { type => data.merge(:version => /\A\d+\Z/) }) do
          clients(:custom, auth_details.merge(:server => :remote)).profile.update(type, data)
        end
      end

      create_another_type = describe "PUT /profile/:type (when explicitly authorized and :type does not exist)", :depends_on => create_authorizations do
        auth_details = get(:explicit_authorization_details)
        data = JSONGenerator.generate(:profile, :example)
        type = get(:example_profile_type_uri)
        expect_response(:tent, :schema => :profile, :status => 200, :properties => { type => data.merge(:version => /\A\d+\Z/) }) do
          clients(:custom, auth_details.merge(:server => :remote)).profile.update(type, data)
        end
      end

      update_another_type = describe "PUT /profile/:type (when explicitly authorized and :type exists)", :depends_on => create_another_type do
        auth_details = get(:explicit_authorization_details)
        data = JSONGenerator.generate(:profile, :example)
        type = get(:example_profile_type_uri)
        expect_response(:tent, :schema => :profile, :status => 200, :properties => { type => data.merge(:version => /\A\d+\Z/) }) do
          clients(:custom, auth_details.merge(:server => :remote)).profile.update(type, data)
        end
      end

      describe "PUT /profile/:type (when unauthorized and :type exists)", :depends_on => create_authorizations do
        auth_details = get(:explicit_unauthorization_details)
        data = JSONGenerator.generate(:profile, :core)
        type = get(:core_profile_type_uri)
        expect_response(:tent, :schema => :error, :status => 403) do
          clients(:custom, auth_details.merge(:server => :remote)).profile.update(type, data)
        end
      end

      describe "PUT /profile/:type (when unauthorized and :type does not exist)", :depends_on => create_authorizations do
        auth_details = get(:explicit_unauthorization_details)
        data = JSONGenerator.generate(:profile, :bogus)
        type = get(:bogus_profile_type_uri)
        expect_response(:tent, :schema => :error, :status => 403) do
          clients(:custom, auth_details.merge(:server => :remote)).profile.update(type, data)
        end
      end

      describe "GET /profile (public)", :depends_on => create_authorizations
        # TODO: validate presence of core profile type

      describe "GET /profile (private when fully authorized)", :depends_on => create_type
        # TODO: validate presence of private section created in a PUT validation

      describe "GET /profile (private when explicitly authorized)", :depends_on => update_another_type
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

      describe "DELETE /profile/:type (when explicitly authorized and :type exists)", :depends_on => update_another_type
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
