require 'tentd/core_ext/hash/slice'

module TentValidator
  module Spec
    class PostsValidation < Validation
      create_authorizations = describe "Create authorizations" do
        app = create_resource(:app, { :server => :remote }, :with_auth)
        set(:app, app)

        app_authorization = create_resource(:app_authorization, { :server => :remote }, :with_auth, :scopes => %w[ read_posts write_posts ], :post_types => %w[ all ])
        set(:full_authorization_details, app_authorization.slice(:mac_key_id, :mac_key, :mac_algorithm))

        app_authorization = create_resource(:app_authorization, { :server => :remote }, :with_auth, :scopes => %w[ read_posts write_posts ], :post_types => %w[ https://tent.io/types/post/status/v0.1.0 ])
        set(:limited_authorization_details, app_authorization.slice(:mac_key_id, :mac_key, :mac_algorithm))

        app_authorization = create_resource(:app_authorization, { :server => :remote }, :with_auth, :scopes => %w[ read_posts ], :post_types => %w[ all ])
        set(:full_read_authorization_details, app_authorization.slice(:mac_key_id, :mac_key, :mac_algorithm))

        app_authorization = create_resource(:app_authorization, { :server => :remote }, :with_auth, :scopes => %w[ read_posts write_posts ], :post_types => %w[ https://tent.io/types/post/status/v0.1.0 ])
        set(:limited_read_authorization_details, app_authorization.slice(:mac_key_id, :mac_key, :mac_algorithm))
      end

      describe "OPTIONS /posts" do
        expect_response :tent_cors, :status => 200 do
          clients(:no_auth, :server => :remote).http.options("posts")
        end
      end

      describe "OPTIONS /posts/:id" do
        expect_response :tent_cors, :status => 200 do
          clients(:no_auth, :server => :remote).http.options("posts/abc")
        end
      end

      describe "OPTIONS /posts/:entity/:id" do
        expect_response :tent_cors, :status => 200 do
          clients(:no_auth, :server => :remote).http.options("posts/etd/abc")
        end
      end

      describe "OPTIONS /posts/:entity/:id/versions" do
        expect_response :tent_cors, :status => 200 do
          clients(:no_auth, :server => :remote).http.options("posts/etd/abc/versions")
        end
      end

      describe "OPTIONS /posts/:entity/:id/attachments" do
        expect_response :tent_cors, :status => 200 do
          clients(:no_auth, :server => :remote).http.options("posts/etd/abc/attachments")
        end
      end

      describe "OPTIONS /posts/:entity/:id/attachments/:name" do
        expect_response :tent_cors, :status => 200 do
          clients(:no_auth, :server => :remote).http.options("posts/etd/abc/attachments/ace")
        end
      end

      describe "OPTIONS /posts/:id/versions" do
        expect_response :tent_cors, :status => 200 do
          clients(:no_auth, :server => :remote).http.options("posts/abc/versions")
        end
      end

      describe "OPTIONS /posts/:id/mentions" do
        expect_response :tent_cors, :status => 200 do
          clients(:no_auth, :server => :remote).http.options("posts/abc/mentions")
        end
      end

      describe "OPTIONS /posts/:id/attachments/:name" do
        expect_response :tent_cors, :status => 200 do
          clients(:no_auth, :server => :remote).http.options("posts/abc/attachments/fed")
        end
      end

      describe "OPTIONS /posts/:id/attachments/:name" do
        expect_response :tent_cors, :status => 200 do
          clients(:no_auth, :server => :remote).http.options("posts/abc/attachments/fed")
        end
      end
    end
  end
end
