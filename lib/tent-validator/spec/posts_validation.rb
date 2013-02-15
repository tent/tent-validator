require 'tentd/core_ext/hash/slice'

module TentValidator
  module Spec
    class PostsValidation < Validation
      create_authorizations = describe "Create authorizations" do
        app = create_resource(:app, { :server => :remote }, :with_auth).data
        set(:app, app)

        app_authorization = create_resource(:app_authorization, { :server => :remote, :client_args => [app[:id]] }, :with_auth, :scopes => %w[ read_posts write_posts ], :post_types => %w[ all ]).data
        set(:full_authorization_details, app_authorization.slice(:mac_key_id, :mac_key, :mac_algorithm))

        app_authorization = create_resource(:app_authorization, { :server => :remote, :client_args => [app[:id]] }, :with_auth, :scopes => %w[ read_posts write_posts ], :post_types => %w[ https://tent.io/types/post/status/v0.1.0 ]).data
        set(:limited_authorization_details, app_authorization.slice(:mac_key_id, :mac_key, :mac_algorithm))

        app_authorization = create_resource(:app_authorization, { :server => :remote, :client_args => [app[:id]] }, :with_auth, :scopes => %w[ read_posts ], :post_types => %w[ all ]).data
        set(:full_read_authorization_details, app_authorization.slice(:mac_key_id, :mac_key, :mac_algorithm))

        app_authorization = create_resource(:app_authorization, { :server => :remote, :client_args => [app[:id]] }, :with_auth, :scopes => %w[ read_posts write_posts ], :post_types => %w[ https://tent.io/types/post/status/v0.1.0 ]).data
        set(:limited_read_authorization_details, app_authorization.slice(:mac_key_id, :mac_key, :mac_algorithm))

        following = create_resource(:following, { :server => :remote }, :with_auth)
        set(:follow_auth_details, following.data.slice(:mac_key_id, :mac_key, :mac_algorithm))
        set(:follow_entity, following.data.entity)
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
      # - type
      # - licenses
      # - content
      # - published_at
      # - mentions
      # - views
      describe "POST /posts (when authorized via app)", :depends_on => create_authorizations do
        app = get(:app)
        auth_details = get(:full_authorization_details)
        base_expected_data = {
          :app => app.slice(:name, :url),
          :entity => TentValidator.remote_entity
        }

        status_data = JSONGenerator.generate(:post, :status, :permissions => { :public => false })
        expect_response(:tent, :schema => :post_status, :status => 200, :properties => status_data.merge(base_expected_data)) do
          clients(:custom, auth_details.merge(:server => :remote)).post.create(status_data)
        end

        custom_data = JSONGenerator.generate(:post, :custom, :permissions => { :public => false })
        views = {
          :soap => ['bars/soap'],
          :candy => ['bars/candy'],
          :bars => ['bars'],
          :kit => ['foos/kips/kit'],
          :variety => ['bars/candy', 'foos/kips/klop', 'foos/bar']
        }
        expect_response(:tent, :schema => :post, :status => 200, :properties => custom_data.merge(base_expected_data)) do
          clients(:custom, auth_details.merge(:server => :remote)).post.create(custom_data.merge(:views => views))
        end

        essay_data = JSONGenerator.generate(:post, :essay, :permissions => { :public => false })
        expect_response(:tent, :schema => :post_essay, :status => 200, :properties => essay_data.merge(base_expected_data)) do
          clients(:custom, auth_details.merge(:server => :remote)).post.create(essay_data.merge(:entity => Faker::Internet.url))
        end

        photo_data = JSONGenerator.generate(:post, :photo, :permissions => { :public => false})
        photo_attachments = JSONGenerator.generate(:post, :attachments, 3)
        photo_attachments_embeded = photo_attachments.map do |a|
          { :name => a[:filename], :size => a[:data].bytesize, :type => a[:type], :category => a[:category] }
        end
        expect_response(:tent, :schema => :post_photo, :status => 200, :properties => photo_data.merge(base_expected_data).merge(:attachments => photo_attachments_embeded)) do
          clients(:custom, auth_details.merge(:server => :remote)).post.create(photo_data, :attachments => photo_attachments)
        end
      end

      describe "POST /posts (when authorized via app with only read_posts)", :depends_on => create_authorizations do
        app = get(:app)
        auth_details = get(:full_read_authorization_details)
        base_data = {
          :app => app.slice(:name, :url),
          :entity => TentValidator.remote_entity
        }

        data = JSONGenerator.generate(:post, :status, :permissions => { :public => false }).merge(base_data)
        expect_response(:tent, :schema => :error, :status => 403) do
          clients(:custom, auth_details.merge(:server => :remote)).post.create(data)
        end

        expect_response(:tent, :schema => :error, :status => 403) do
          clients(:custom, auth_details.merge(:server => :remote)).post.create(data.merge(:entity => Faker::Internet.url))
        end

        expect_response(:tent, :schema => :error, :status => 403) do
          clients(:custom, auth_details.merge(:server => :remote)).post.create(data.merge(:entity => get(:follow_entity)))
        end
      end

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
      describe "POST /posts (when authorized via follow relationship)", :depends_on => create_authorizations do
        auth_details = get(:follow_auth_details)
        base_data = {
          :entity => get(:follow_entity),
          :app => { :name => Faker::Name.name, :url => Faker::Internet.url }
        }

        data = JSONGenerator.generate(:post, :status, :permissions => { :public => false }).merge(base_data)
        expect_response(:tent, :schema => :post_status, :status => 200, :properties => data) do
          clients(:custom, auth_details.merge(:server => :remote)).post.create(data)
        end

        expect_response(:tent, :schema => :error, :status => 403) do
          clients(:custom, auth_details.merge(:server => :remote)).post.create(data.merge(:entity => TentValidator.remote_entity))
        end

        photo_data = JSONGenerator.generate(:post, :photo, :permissions => { :public => false}).merge(base_data)
        photo_attachments = JSONGenerator.generate(:post, :attachments, 3)
        photo_attachments_embeded = photo_attachments.map do |a|
          { :name => a[:filename], :size => a[:data].bytesize, :type => a[:type], :category => a[:category] }
        end
        expect_response(:tent, :schema => :post_photo, :status => 200, :properties => photo_data.merge(:attachments => photo_attachments_embeded)) do
          clients(:custom, auth_details.merge(:server => :remote)).post.create(photo_data, :attachments => photo_attachments)
        end
      end

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
      describe "POST /posts (when not authorized)", :depends_on => create_authorizations do
        base_data = {
          :entity => Faker::Internet.url,
          :app => { :name => Faker::Name.name, :url => Faker::Internet.url }
        }

        data = JSONGenerator.generate(:post, :status, :permissions => { :public => false }).merge(base_data)
        expect_response(:tent, :schema => :post_status, :status => 200, :properties => data) do
          clients(:no_auth, :server => :remote).post.create(data)
        end

        expect_response(:tent, :schema => :error, :status => 403) do
          clients(:no_auth, :server => :remote).post.create(data.merge(:entity => TentValidator.remote_entity))
        end

        expect_response(:tent, :schema => :error, :status => 403) do
          clients(:no_auth, :server => :remote).post.create(data.merge(:entity => get(:follow_entity)))
        end

        photo_data = JSONGenerator.generate(:post, :photo, :permissions => { :public => false}).merge(base_data)
        photo_attachments = JSONGenerator.generate(:post, :attachments, 3)
        photo_attachments_embeded = photo_attachments.map do |a|
          { :name => a[:filename], :size => a[:data].bytesize, :type => a[:type], :category => a[:category] }
        end
        expect_response(:tent, :schema => :post_photo, :status => 200, :properties => photo_data.merge(:attachments => photo_attachments_embeded)) do
          clients(:no_auth, :server => :remote).post.create(photo_data, :attachments => photo_attachments)
        end
      end

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
