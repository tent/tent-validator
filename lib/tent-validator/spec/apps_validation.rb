module TentValidator
  module Spec
    class AppsValidation < Validation
      # OPTIONS /apps should
      #   - set CORS headers
      describe "OPTIONS /apps" do
        with_client :app, :server => :remote do
          expect_response :tent_cors, :status => 200 do
            client.http.options("apps")
          end
        end
      end

      # HEAD /apps should
      #   - (when authorized) set Content-Type, Count, and Content-Length headers
      #   - TODO: validate pagination in Link header
      #   - (when unauthorized) return 403
      describe "HEAD /apps (when authorized)" do
        with_client :app, :server => :remote do
          expect_response :tent_head, :status => 200 do
            client.http.head("apps")
          end
        end
      end

      describe "HEAD /apps (when unauthorized)" do
        with_client :no_auth, :server => :remote do
          expect_response :void, :status => 403 do
            client.http.head("apps")
          end
        end
      end

      # GET /apps should
      #   - (when authorized) return a list of apps conforming to the app json schema
      #   - TODO: validate pagination in Link header
      #   - (when unauthorized) return 403 with a valid json error response
      list_apps = describe "GET /apps (when authorized)" do
        with_client :app, :server => :remote do
          expect_response(:tent, :schema => :app, :list => true, :status => 200) do
            client.app.list
          end.after do |result|
            if result.response.success?
              # We can assume there is at least one app (this app)
              set(:app_id, result.response.body.first['id'])
            end
          end
        end
      end

      describe "GET /apps (when unauthorized)" do
        with_client :no_auth, :server => :remote do
          expect_response :tent, :schema => :error, :status => 403 do
            client.app.list
          end
        end
      end

      # GET /apps/:id should
      #   - (when authorized and app exists) return app with spcified id conforming to the app json schema
      #   - (when authorized and app not found) return 404 with a valid json error response
      #   - (when unauthorized) return 404 with a valid json error response
      describe "GET /apps/:id (when authorized via scope)", :depends_on => list_apps do
        with_client :app, :server => :remote do
          expect_response :tent, :schema => :app, :status => 200, :properties => { :id => get(:app_id) } do
            client.app.get(get(:app_id))
          end
        end
      end

      # POST /apps should
      #   - create and return app
      #   - (when authorized to import) it should create app with specified credentials
      #   - (when authorized to import) it should create app with generated credentials when none specified
      describe "POST /apps" do
        with_client :no_auth, :server => :remote do
          app = JSONGenerator.generate(:app, :simple)
          expect_response :tent, :schema => :app, :status => 200, :properties => app.merge(
            :mac_key_id => /\A\S+\Z/,
            :mac_algorithm => 'hmac-sha-256',
            :mac_key => /\A\S+\Z/
          ) do
            client.app.create(app)
          end
        end
      end

      describe "POST /apps (when import authorized)" do
        with_client :app, :server => :remote do
          app = JSONGenerator.generate(:app, :with_auth)
          expect_response :tent, :schema => :app, :status => 200, :properties => app do
            client.app.create(app)
          end

          simple_app = JSONGenerator.generate(:app, :simple)
          expect_response :tent, :schema => :app, :status => 200, :properties => simple_app.merge(
            :mac_key_id => /\A\S+\Z/,
            :mac_algorithm => 'hmac-sha-256',
            :mac_key => /\A\S+\Z/
          ) do
            client.app.create(simple_app)
          end
        end
      end

      # PUT /apps/:id should
      #   - (when authorized and app exists) update app registration
      #   - TODO: should an app be able to request new auth credentials?
      #   - (when authorized with write_secrets and app exists) update auth credentials
      #   - (when authorized and app not found) return 404 with valida json error response
      #   - (when unauthorized) return 404 with valid json error response
      describe "PUT /apps/:id (when authorized)"

      describe "PUT /apps/:id (when write_secrets authorized)"

      describe "PUT /apps/:id (when unauthorized)"

      # 1. Create new app
      # 2. Use auth credentials of new app to get that new app
      # (depends on POST /apps)
      describe "GET /apps/:id (when authorized via identity)"

      describe "GET /apps/:id (when unauthorized)"

      # DELETE /apps/:id should
      #   - when authorized
      #     - delete app
      #   - when unauthorized
      #     - return 404 with valid json error response
      describe "DELETE /apps/:id (when authorized via scope)"

      describe "DELETE /apps/:id (when authorized via identity)"

      describe "DELETE /apps/:id (when unauthorized)"

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
      describe "POST /apps/:id/authorizations (when authorized)"

      describe "POST /apps/:id/authorizations (when write_apps and write_secrets authorized)"

      describe "POST /apps/:id/authorizations (when unauthorized)"

      # PUT /apps/:id/authorizations/:id should
      #   - when write_apps authorized
      #     - update authorization
      #     - TODO: test changing post types subscribed to updates notification subscription(s)
      #   - when write_apps unauthorized
      #     - return 404 with valid json error response
      describe "PUT /apps/:id/authorization/:id (when write_apps authorized)"

      describe "PUT /apps/:id/authorization/:id (when write_apps unauthorized)"

      # DELETE /apps/:id/authorizations/:id should
      #   - when authorized
      #     - delete authorization
      #   - when unauthorized
      #     - return 404 with valid json error response
      describe "DELETE /apps/:id/authorizations/:id (when authorized)"

      describe "DELETE /apps/:id/authorizations/:id (when unauthorized)"
    end
  end
end
