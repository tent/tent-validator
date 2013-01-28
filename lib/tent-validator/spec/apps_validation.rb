module TentValidator
  module Spec
    class AppsValidation < Validation
      # OPTIONS /apps should
      #   - set CORS headers
      describe "OPTIONS /apps" do
        expect_response :tent_cors, :status => 200 do
          clients(:app, :server => :remote).http.options("apps")
        end
      end

      # HEAD /apps should
      #   - (when authorized) set Content-Type, Count, and Content-Length headers
      #   - TODO: validate pagination in Link header
      #   - (when unauthorized) return 403
      describe "HEAD /apps (when authorized)" do
        expect_response :tent_head, :status => 200 do
          clients(:app, :server => :remote).http.head("apps")
        end
      end

      describe "HEAD /apps (when unauthorized)" do
        expect_response :void, :status => 403 do
          clients(:no_auth, :server => :remote).http.head("apps")
        end
      end

      # GET /apps should
      #   - (when authorized) return a list of apps conforming to the app json schema
      #   - TODO: validate pagination in Link header
      #   - (when unauthorized) return 403 with a valid json error response
      list_apps = describe "GET /apps (when authorized)" do
        expect_response(:tent, :schema => :app, :list => true, :status => 200, :excluded_properties => [:mac_key_id, :mac_algorithm, :mac_key]) do
          clients(:app, :server => :remote).app.list
        end.after do |result|
          if result.response.success?
            # We can assume there is at least one app (this app)
            set(:app_id, result.response.body.first['id'])
          end
        end
      end

      describe "GET /apps (when read_secrets authorized and secrets param present)" do
        expect_response(:tent, :schema => :app, :list => true, :status => 200, :properties => {
          :mac_key_id => /\A\S+\Z/,
          :mac_algorithm => 'hmac-sha-256',
          :mac_key => /\A\S+\Z/
        }) do
          clients(:app, :server => :remote).app.list(:secrets => true)
        end
      end

      describe "GET /apps (when unauthorized)" do
        expect_response :tent, :schema => :error, :status => 403 do
          clients(:no_auth, :server => :remote).app.list
        end
      end

      # POST /apps should
      #   - create and return app
      #   - (when authorized to import) it should create app with specified credentials
      #   - (when authorized to import) it should create app with generated credentials when none specified
      create_app = describe "POST /apps" do
        app = JSONGenerator.generate(:app, :simple)
        expect_response(:tent, :schema => :app, :status => 200, :properties => app.merge(
          :mac_key_id => /\A\S+\Z/,
          :mac_algorithm => 'hmac-sha-256',
          :mac_key => /\A\S+\Z/
        )) do
          clients(:no_auth, :server => :remote).app.create(app)
        end.after do |result|
          if result.response.success?
            set(:app, result.response.body)
          end
        end
      end

      import_app = describe "POST /apps (when import authorized)" do
        app = JSONGenerator.generate(:app, :with_auth)
        expect_response :tent, :schema => :app, :status => 200, :properties => app do
          clients(:app, :server => :remote).app.create(app)
        end

        simple_app = JSONGenerator.generate(:app, :simple)
        expect_response(:tent, :schema => :app, :status => 200, :properties => simple_app.merge(
          :mac_key_id => /\A\S+\Z/,
          :mac_algorithm => 'hmac-sha-256',
          :mac_key => /\A\S+\Z/
        )) do
          clients(:app, :server => :remote).app.create(simple_app)
        end.after do |result|
          if result.response.success?
            set(:app, result.response.body)
          end
        end
      end

      # GET /apps/:id should
      #   - (when authorized and app exists) return app with spcified id conforming to the app json schema
      #   - (when authorized and app not found) return 404 with a valid json error response
      #   - (when unauthorized) return 403 with a valid json error response
      describe "GET /apps/:id (when authorized via scope)", :depends_on => list_apps do
        expect_response :tent, :schema => :app, :status => 200, :properties => { :id => get(:app_id) }, :excluded_properties => [:mac_key_id, :mac_algorithm, :mac_key] do
          clients(:app, :server => :remote).app.get(get(:app_id))
        end
      end

      describe "GET /apps/:id (when authorized via identity)", :depends_on => create_app do
        app = get(:app)
        auth_details = {
          :mac_key_id => app['mac_key_id'], :mac_algorithm => app['mac_algorithm'], :mac_key => app['mac_key']
        }
        expect_response(:tent, :schema => :app, :status => 200, :properties => { :id => app['id'] }, :excluded_properties => [:mac_key_id, :mac_algorithm, :mac_key]) do
          clients(:custom, auth_details.merge(:server => :remote)).app.get(app['id'])
        end
      end

      describe "GET /apps/:id (when unauthorized)", :depends_on => create_app do
        app = get(:app)
        expect_response(:tent, :schema => :error, :status => 403) do
          clients(:no_auth, :server => :remote).app.get(app['id'])
        end
      end

      # POST /apps/:id/authorizations should
      #   - when authorized for token exchange
      #     - update/set expirey to something sooner than currently set
      #     - return refresh_token, and mac auth credentials
      #     - return expirey if set
      #     - TODO: should this also cycle the mac auth credentials?
      #   - when write_apps and write_secrets authorized
      #     - create authorization with specified auth credentials
      #     - create authorization and generate auth credentials when not specified
      #   - when unauthorized
      #     - return 403 with valid json error response
      create_authorization = describe "POST /apps/:id/authorizations (when write_apps and write_secrets authorized)", :depends_on => create_app do
        app = get(:app)
        authorization = JSONGenerator.generate(:app_authorization, :simple, :scopes => %w[ read_apps ])
        expect_response(:tent, :schema => :app_authorization, :status => 200, :properties => authorization.merge(
          :token_code => /\A\S+\Z/
        )) do
          clients(:app, :server => :remote).app.authorization.create(app['id'], authorization)
        end.after do |result|
          if result.response.success?
            set(:app_authorization, result.response.body)
          end
        end
      end

      token_exchange = describe "POST /apps/:id/authorizations (when authorized)", :depends_on => create_authorization do
        app = get(:app)
        authorization = get(:app_authorization)
        auth_details = {
          :mac_key_id => app['mac_key_id'], :mac_algorithm => app['mac_algorithm'], :mac_key => app['mac_key']
        }
        expect_response(:tent, :schema => :app_authorization, :status => 200, :properties => {
          :access_token => /\A\S+\Z/,
          :token_type => 'mac',
          :refresh_token => /\A\S+\Z/,
          :mac_key => /\A\S+\Z/,
          :mac_algorithm => 'hmac-sha-256',
        }) do
          clients(:custom, auth_details.merge(:server => :remote)).app.authorization.create(app['id'], :code => authorization['token_code'], :token_type => 'mac')
        end.after do |result|
          if result.response.success?
            authorization['token_code'] = result.response.body['refresh_token']
          end
        end

        tent_expires_at = Time.now.to_i + (86400 * 20) # 20 days from now

        expect_response(:tent, :schema => :app_authorization, :status => 200, :properties => {
          :access_token => /\A\S+\Z/,
          :token_type => 'mac',
          :refresh_token => /\A\S+\Z/,
          :mac_key => /\A\S+\Z/,
          :mac_algorithm => 'hmac-sha-256',
          :tent_expires_at => tent_expires_at
        }) do
          clients(:custom, auth_details.merge(:server => :remote)).app.authorization.create(app['id'], :code => authorization['token_code'], :token_type => 'mac', :tent_expires_at => tent_expires_at)
        end.after do |result|
          if result.response.success?
            authorization.merge!(result.response.body)
            authorization['token_code'] = result.response.body['refresh_token']
          end
        end
      end

      describe "POST /apps/:id/authorization (when refresh_token expired)", :depends_on => token_exchange do
        app = get(:app)
        authorization = get(:app_authorization)
        auth_details = {
          :mac_key_id => app['mac_key_id'], :mac_algorithm => app['mac_algorithm'], :mac_key => app['mac_key']
        }
        tent_expires_at = Time.now.to_i - 1

        expect_response(:void, :status => 200) do
          auth = {
            :mac_key_id => authorization['access_token'], :mac_algorithm => authorization['mac_algorithm'], :mac_key => authorization['mac_key']
          }
          clients(:custom, auth.merge(:server => :remote)).app.list
        end

        expect_response(:tent, :schema => :app_authorization, :status => 200, :properties => {
          :access_token => /\A\S+\Z/,
          :token_type => 'mac',
          :refresh_token => /\A\S+\Z/,
          :mac_key => /\A\S+\Z/,
          :mac_algorithm => 'hmac-sha-256',
          :tent_expires_at => tent_expires_at
        }) do
          clients(:custom, auth_details.merge(:server => :remote)).app.authorization.create(app['id'], :code => authorization['token_code'], :token_type => 'mac', :tent_expires_at => tent_expires_at)
        end.after do |result|
          if result.response.success?
            authorization.merge!(result.response.body)
          end
        end

        # as the authorization should now be expired, the mac_key_id should not be found causing a 401
        expect_response(:tent, :schema => :error, :status => 401) do
          auth = {
            :mac_key_id => authorization['access_token'], :mac_algorithm => authorization['mac_algorithm'], :mac_key => authorization['mac_key']
          }
          clients(:custom, auth.merge(:server => :remote)).app.list
        end
      end

      describe "POST /apps/:id/authorizations (when unauthorized)", :depends_on => create_authorization do
        app = get(:app)
        authorization = get(:app_authorization)
        expect_response(:tent, :schema => :error, :status => 403) do
          clients(:no_auth, :server => :remote).app.authorization.create(app['id'], :code => authorization['token_code'], :token_type => 'mac')
        end
      end

      # PUT /apps/:id/authorizations/:id should
      #   - when write_apps authorized
      #     - update authorization
      #     - TODO: test changing post types subscribed to updates notification subscription(s)
      #   - when write_apps unauthorized
      #     - return 404 with valid json error response
      describe "PUT /apps/:id/authorization/:id (when write_apps authorized via scope)", :depends_on => create_authorization do
        app = get(:app)
        authorization = get(:app_authorization)
        data = JSONGenerator.generate(:app_authorization, :simple)
        expect_response(:tent, :schema => :app_authorization, :status => 200, :properties => data) do
          clients(:app, :server => :remote).app.authorization.update(app['id'], authorization['id'], data)
        end
      end

      describe "PUT /apps/:id/authorization/:id (when write_apps unauthorized)", :depends_on => create_authorization do
        app = get(:app)
        authorization = get(:app_authorization)
        data = JSONGenerator.generate(:app_authorization, :simple)
        expect_response(:tent, :schema => :error, :status => 403) do
          clients(:no_auth, :server => :remote).app.authorization.update(app['id'], authorization['id'], data)
        end
      end

      describe "PUT /apps/:id/authorization/:id (when app mac authorized)", :depends_on => create_authorization do
        app = get(:app)
        authorization = get(:app_authorization)
        data = JSONGenerator.generate(:app_authorization, :simple)
        auth_details = {
          :mac_key_id => app['mac_key_id'], :mac_algorithm => app['mac_algorithm'], :mac_key => app['mac_key']
        }
        expect_response(:tent, :schema => :error, :status => 403) do
          clients(:custom, auth_details.merge(:server => :remote)).app.authorization.update(app['id'], authorization['id'], data)
        end
      end

      # DELETE /apps/:id/authorizations/:id should
      #   - when authorized
      #     - delete authorization
      #   - when unauthorized
      #     - return 403 with valid json error response
      describe "DELETE /apps/:id/authorizations/:id (when authorized via scope)", :depends_on => create_authorization do
        app = get(:app)
        authorization = get(:app_authorization)
        expect_response(:void, :status => 200) do
          clients(:app, :server => :remote).app.authorization.delete(app['id'], authorization['id'])
        end
      end

      describe "DELETE /apps/:id/authorizations/:id (when authorized via identity)", :depends_on => create_app do
        app = get(:app)
        authorization = JSONGenerator.generate(:app_authorization, :with_auth)
        expect_response(:tent, :schema => :app_authorization, :status => 200) do
          clients(:app, :server => :remote).app.authorization.create(app['id'], authorization)
        end

        auth_details = {
          :mac_key_id => app['mac_key_id'], :mac_algorithm => app['mac_algorithm'], :mac_key => app['mac_key']
        }
        expect_response(:void, :status => 200) do
          clients(:custom, auth_details.merge(:server => :remote)).app.authorization.delete(app['id'], authorization[:id])
        end
      end

      describe "DELETE /apps/:id/authorizations/:id (when unauthorized)", :depends_on => create_authorization do
        app = get(:app)
        authorization = get(:app_authorization)
        expect_response(:void, :status => 403) do
          clients(:no_auth, :server => :remote).app.authorization.delete(app['id'], authorization['id'])
        end
      end

      # PUT /apps/:id should
      #   - (when authorized and app exists) update app registration
      #   - TODO: should an app be able to request new auth credentials?
      #   - (when authorized with write_secrets and app exists) update auth credentials
      #   - (when authorized and app not found) return 403 with valida json error response
      #   - (when unauthorized) return 404 with valid json error response
      describe "PUT /apps/:id (when authorized via identity)", :depends_on => create_app do
        app = get(:app)
        auth_details = {
          :mac_key_id => app['mac_key_id'], :mac_algorithm => app['mac_algorithm'], :mac_key => app['mac_key']
        }
        updated_app = JSONGenerator.generate(:app, :simple)
        expect_response(:tent, :schema => :app, :status => 200, :properties => updated_app.merge('id' => app['id']), :excluded_properties => [:mac_key_id, :mac_algorithm, :mac_key]) do
          clients(:custom, auth_details.merge(:server => :remote)).app.update(app['id'], updated_app)
        end
      end

      describe "PUT /apps/:id (when authorized via scope)", :depends_on => create_app do
        app = get(:app)
        updated_app = JSONGenerator.generate(:app, :simple)
        expect_response(:tent, :schema => :app, :status => 200, :properties => updated_app.merge('id' => app['id']), :excluded_properties => [:mac_key_id, :mac_algorithm, :mac_key]) do
          clients(:app, :server => :remote).app.update(app['id'], updated_app)
        end
      end

      describe "PUT /apps/:id (when write_secrets authorized and secrets params passed)", :depends_on => import_app do
        app = get(:app)
        updated_app = JSONGenerator.generate(:app, :with_auth)
        expect_response(:tent, :schema => :app, :status => 200, :properties => updated_app.merge(:id => app['id'])) do
          clients(:app, :server => :remote).app.update(app['id'] + "?secrets=true", updated_app)
        end
      end

      describe "PUT /apps/:id (when unauthorized)", :depends_on => create_app do
        app = get(:app)
        updated_app = JSONGenerator.generate(:app, :simple)
        expect_response(:tent, :schema => :error, :status => 403) do
          clients(:no_auth, :server => :remote).app.update(app['id'], updated_app)
        end
      end

      # DELETE /apps/:id should
      #   - when authorized
      #     - delete app
      #   - when unauthorized
      #     - return 403 with valid json error response
      describe "DELETE /apps/:id (when authorized via scope)", :depends_on => import_app do
        app = get(:app)
        expect_response(:void, :status => 200) do
          clients(:app, :server => :remote).app.delete(app['id'])
        end
      end

      describe "DELETE /apps/:id (when authorized via identity)", :depends_on => create_app do
        app = get(:app)
        auth_details = {
          :mac_key_id => app['mac_key_id'], :mac_algorithm => app['mac_algorithm'], :mac_key => app['mac_key']
        }
        expect_response(:void, :status => 200) do
          clients(:custom, auth_details.merge(:server => :remote)).app.delete(app['id'])
        end
      end

      describe "DELETE /apps/:id (when unauthorized)", :depends_on => list_apps do
        app_id = get(:app_id)
        expect_response(:tent, :status => 403, :schema => :error) do
          clients(:no_auth, :server => :remote).app.delete(app_id)
        end
      end
    end
  end
end
