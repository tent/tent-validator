require 'tent-validator/validators/post_validator'
require 'tent-validator/validators/support/app_post_generators'

module TentValidator
  module WithoutAuthentication

    class AppValidator < PostValidator
      include Support::AppPostGenerators

      describe "POST /posts" do
        context "without authentication" do

          set(:client) { clients(:no_auth, :server => :remote) }

          context "when app registration post", :name => :create_app_registration_post do
            set(:post) { generate_app_post }
            set(:content_schema, :post_app)

            behaves_as(:new_post)

            context "with icon attachment" do
              set(:post_attachments) { [generate_app_icon_attachment] }

              behaves_as(:new_post)
            end

            ##
            # Expect app credentials post linked
            expect_response(:status => 200, :schema => :data) do
              expect_schema(:post, '/post')

              expect_headers(
                :Link => %r{\brel=(['"])https://tent.io/rels/credentials\1}
              )

              res = get(:client).post.create(get(:post))

              res
            end
          end

        end
      end
    end

  end

  TentValidator.validators << WithoutAuthentication::AppValidator
end
