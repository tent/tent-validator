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

      # - native entity only
      # - permissions
      # - app_name
      # - app_url
      # - type
      # - licenses
      # - content
      # - published_at
      # - mentions
      # - views
      describe "POST /posts (when authorized via app)"

      # - any entity
      # - permissions
      # - app_name
      # - app_url
      # - type
      # - licenses
      # - content
      # - published_at
      # - received_at
      # - mentions
      # - views
      describe "POST /posts (when authorized via app with write_secrets)"

      # - following entity
      # - permissions
      # - app_name
      # - app_url
      # - type
      # - licenses
      # - content
      # - published_at
      # - mentions
      # - views
      describe "POST /posts (when authorized via follow relationship)"

      # - any entity (except native or any following entities)
      # - permissions
      # - app_name
      # - app_url
      # - type
      # - licenses
      # - content
      # - published_at
      # - mentions
      # - views
      describe "POST /posts (when not authorized)"

      describe "GET /posts/:id (when authorized via app)"

      # 403
      describe "GET /posts/:id (when authorized via app only for write_posts)"

      # 403 if post type not authorized
      describe "GET /posts/:id (when authorized via app for specific post type)"

      describe "GET /posts/:id (when authorized via follow relationship)"

      describe "GET /posts/:id (when not authorized)"

      # - licenses
      # - mentions
      # - views
      describe "PUT /posts/:id (when authorized via app)"

      # - licenses
      # - mentions
      # - views
      # 403 if post type not authorized
      describe "PUT /posts/:id (when authorized via app for specific post type)"

      # 403
      describe "PUT /posts/:id (when authorized via app only for read_posts)"

      # 403
      describe "PUT /posts/:id (when not authorized)"

      describe "DELETE /posts/:id (when authorized via app)"

      # 403
      describe "DELETE /posts/:id (when authorized via app only for read_posts)"

      # 403
      describe "DELETE /posts/:id (when not authorized)"

      describe "GET /posts (when authorized via app)"

      describe "GET /posts (when authorized via app only for write_posts)"

      describe "GET /posts (when authorized via app for specific post type)"

      describe "GET /posts (when authorized via follow relationship)"

      describe "GET /posts (when not authorized)"

      # TODO: GET /posts/:id/versions
      # TODO: GET /posts/:id/attachments/:name
      # TODO: GET /posts/:id/mentions
      # TODO: POST /posts/:id/attachments
      # TODO: POST /posts with attachments
      # TODO: GET /posts/:entity/:id
      # TODO: GET /posts/:entity/:id/attachments/:name
      # TODO: GET /posts/:entity/:id/mentions
      # TODO: GET /posts/:entity/:id/versions
      # TODO: GET /notifications/:following_id
      # TODO: POST /notifications/:following_id
    end
  end
end
