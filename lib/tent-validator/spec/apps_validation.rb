module TentValidator
  module Spec
    class AppsValidation < Validation
      # GET /apps should
      #   - set CORS headers
      #   - (when authorized) return a list of apps conforming to the app json schema
      #   - (when unauthorized) return 403 with a valid json error response
      # TODO: validate pagination in link header
      list_apps = describe "GET /apps (when authorized)" do
        with_client :app, :server => :remote do
          expect_response :tent, :schema => :app, :list => true, :status => 200 do
            res = client.app.list

            # We can assume there is at least one app (this app)
            set(:app_id, res.body.first['id'])

            res
          end
        end
      end

      describe "OPTIONS /apps" do
        with_client :app, :server => :remote do
          expect_response :tent_cors, :status => 200 do
            client.http.options("apps")
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
      #   - set CORS headers
      #   - (when authorized and app exists) return app with spcified id conforming to the app json schema
      #   - (when authorized and app not found) return 404 with a valid json error response
      #   - (when unauthorized) return 403 with a valid json error response
      describe "GET /apps/:id (when authorized via scope)", :depends_on => list_apps do
        with_client :app, :server => :remote do
          expect_response :tent, :schema => :app, :status => 200, :properties => { :id => get(:app_id) } do
            client.app.get(get(:app_id))
          end
        end
      end

      # 1. Create new app
      # 2. Use auth credentials of new app to get that new app
      # (depends on POST /apps)
      describe "GET /apps/:id (when authorized via identity)"

      describe "GET /apps/:id (when unauthorized)"
    end
  end
end
