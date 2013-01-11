module TentValidator
  module Spec
    class HelloWorldValidator < ResponseValidator
      register :hello_world

      def validate(options)
        expect(:body => 'Tent!')
        super
      end
    end

    class AppsValidation < Validation
      describe "GET /" do
        with_client :app, :server => :remote do
          expect_response :hello_world do
            client.http.get('/')
          end
        end
      end
    end
  end
end
