module TentValidator
  module Spec
    class AppsValidation < Validation
      describe "GET /apps" do
        with_client :app, :server => :remote do
          expect_response :tent, :schema => :app, :list => true, :status => 200 do
            client.app.list
          end
        end
      end
    end
  end
end
