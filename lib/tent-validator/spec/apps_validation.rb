module TentValidator
  module Spec
    class AppsValidation < Validation
      list_apps = describe "GET /apps (when authorized)" do
        with_client :app, :server => :remote do
          expect_response :tent, :schema => :app, :list => true, :status => 200 do
            res = client.app.list
            set(:app_id, res.body.first['id'])
            res
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

      describe "GET /apps/:id", :depends_on => list_apps do
        with_client :app, :server => :remote do
          expect_response :tent, :schema => :app, :status => 200, :properties => { :id => get(:app_id) } do
            client.app.get(get(:app_id))
          end
        end
      end
    end
  end
end
