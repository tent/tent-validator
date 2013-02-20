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

        app_authorization = create_resource(:app_authorization, { :server => :remote, :client_args => [app[:id]] }, :with_auth, :scopes => %w[ write_posts ], :post_types => %w[ all ]).data
        set(:full_write_authorization_details, app_authorization.slice(:mac_key_id, :mac_key, :mac_algorithm))

        app_authorization = create_resource(:app_authorization, { :server => :remote, :client_args => [app[:id]] }, :with_auth, :scopes => %w[ read_posts write_posts ], :post_types => %w[ https://tent.io/types/post/status/v0.1.0 ]).data
        set(:limited_status_authorization_details, app_authorization.slice(:mac_key_id, :mac_key, :mac_algorithm))

        app_authorization = create_resource(:app_authorization, { :server => :remote, :client_args => [app[:id]] }, :with_auth, :scopes => %w[ read_posts write_posts ], :post_types => %w[ https://tent.io/types/post/photo/v0.1.0 ]).data
        set(:limited_photo_authorization_details, app_authorization.slice(:mac_key_id, :mac_key, :mac_algorithm))

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
      create_post = describe "POST /posts (when authorized via app)", :depends_on => create_authorizations do
        app = get(:app)
        auth_details = get(:full_authorization_details)
        base_data = {
          :app => app.slice(:name, :url),
          :entity => TentValidator.remote_entity
        }

        status_data = JSONGenerator.generate(:post, :status, :permissions => { :public => false }).merge(base_data)
        expect_response(:tent, :schema => :post_status, :status => 200, :properties => status_data) do
          clients(:custom, auth_details.merge(:server => :remote)).post.create(status_data)
        end.after do |result|
          if result.response.success?
            set(:status_post, status_data.merge(:id => result.response.body['id']))
          end
        end

        custom_data = JSONGenerator.generate(:post, :custom, :permissions => { :public => false }).merge(base_data)
        views = {
          :soap => ['bars/soap'],
          :candy => ['bars/candy'],
          :bars => ['bars'],
          :kit => ['foos/kips/kit'],
          :variety => ['bars/candy', 'foos/kips/klop', 'foos/bar']
        }
        expect_response(:tent, :schema => :post, :status => 200, :properties => custom_data) do
          clients(:custom, auth_details.merge(:server => :remote)).post.create(custom_data.merge(:views => views))
        end.after do |result|
          if result.response.success?
            set(:custom_post, custom_data.merge(:id => result.response.body['id']))
          end
        end

        essay_data = JSONGenerator.generate(:post, :essay, :permissions => { :public => false }).merge(base_data)
        expect_response(:tent, :schema => :post_essay, :status => 200, :properties => essay_data) do
          clients(:custom, auth_details.merge(:server => :remote)).post.create(essay_data.merge(:entity => Faker::Internet.url))
        end.after do |result|
          if result.response.success?
            set(:essay_post, essay_data.merge(:id => result.response.body['id']))
          end
        end

        photo_data = JSONGenerator.generate(:post, :photo, :permissions => { :public => false}).merge(base_data)
        photo_attachments, photo_attachments_embeded = JSONGenerator.generate(:post, :attachments, 3)
        expect_response(:tent, :schema => :post_photo, :status => 200, :properties => photo_data.merge(:attachments => photo_attachments_embeded)) do
          clients(:custom, auth_details.merge(:server => :remote)).post.create(photo_data, :attachments => photo_attachments)
        end.after do |result|
          if result.response.success?
            set(:photo_post, photo_data.merge(:id => result.response.body['id']))
          end
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
      follow_create_post = describe "POST /posts (when authorized via follow relationship)", :depends_on => create_authorizations do
        auth_details = get(:follow_auth_details)
        base_data = {
          :entity => get(:follow_entity),
          :app => { :name => Faker::Name.name, :url => Faker::Internet.url }
        }

        data = JSONGenerator.generate(:post, :status, :permissions => { :public => false }).merge(base_data)
        expect_response(:tent, :schema => :post_status, :status => 200, :properties => data) do
          clients(:custom, auth_details.merge(:server => :remote)).post.create(data)
        end.after do |result|
          if result.response.success?
            set(:status_post, data.merge(:id => result.response.body['id']))
          end
        end

        expect_response(:tent, :schema => :error, :status => 403) do
          clients(:custom, auth_details.merge(:server => :remote)).post.create(data.merge(:entity => TentValidator.remote_entity))
        end

        photo_data = JSONGenerator.generate(:post, :photo, :permissions => { :public => false}).merge(base_data)
        photo_attachments, photo_attachments_embeded = JSONGenerator.generate(:post, :attachments, 3)
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
        photo_attachments, photo_attachments_embeded = JSONGenerator.generate(:post, :attachments, 3)
        expect_response(:tent, :schema => :post_photo, :status => 200, :properties => photo_data.merge(:attachments => photo_attachments_embeded)) do
          clients(:no_auth, :server => :remote).post.create(photo_data, :attachments => photo_attachments)
        end
      end

      describe "GET /posts/:id (when authorized via app)", :depends_on => create_post do
        auth_details = get(:full_authorization_details)
        post = get(:status_post)
        expect_response(:tent, :schema => :post_status, :status => 200, :properties => post) do
          clients(:custom, auth_details.merge(:server => :remote)).post.get(post[:id])
        end
      end

      describe "GET /posts/:id (when authorized via app only for write_posts)", :depends_on => create_post do
        auth_details = get(:full_write_authorization_details)
        post = get(:status_post)
        expect_response(:tent, :schema => :error, :status => 404) do
          clients(:custom, auth_details.merge(:server => :remote)).post.get(post[:id])
        end
      end

      # 404 if post type not authorized
      describe "GET /posts/:id (when authorized via app for specific post type)", :depends_on => create_post do
        post = get(:status_post)

        status_auth_details = get(:limited_status_authorization_details)
        expect_response(:tent, :schema => :post_status, :status => 200, :properties => post) do
          clients(:custom, status_auth_details.merge(:server => :remote)).post.get(post[:id])
        end

        photo_auth_details = get(:limited_photo_authorization_details)
        expect_response(:tent, :schema => :error, :status => 404) do
          clients(:custom, photo_auth_details.merge(:server => :remote)).post.get(post[:id])
        end
      end

      describe "GET /posts/:id (when authorized via follow relationship)", :depends_on => follow_create_post do
        auth_details = get(:follow_auth_details)

        public_post = JSONGenerator.generate(:post, :status, :permissions => { :public => true })
        expect_response(:tent, :schema => :post_status, :status => 200, :properties => public_post) do
          clients(:app, :server => :remote).post.create(public_post)
        end.after do |result|
          if result.response.success?
            public_post[:id] = result.response.body['id']
          end
        end

        expect_response(:tent, :schema => :post_status, :status => 200, :properties => public_post) do
          clients(:custom, auth_details.merge(:server => :remote)).post.get(public_post[:id])
        end

        private_post = get(:status_post)
        expect_response(:tent, :schema => :error, :status => 404) do
          clients(:custom, auth_details.merge(:server => :remote)).post.get(private_post[:id])
        end
      end

      describe "GET /posts/:id (when not authorized)", :depends_on => create_post do
        public_post = JSONGenerator.generate(:post, :status, :permissions => { :public => true })
        expect_response(:tent, :schema => :post_status, :status => 200, :properties => public_post) do
          clients(:app, :server => :remote).post.create(public_post)
        end.after do |result|
          if result.response.success?
            public_post[:id] = result.response.body['id']
          end
        end

        expect_response(:tent, :schema => :post_status, :status => 200, :properties => public_post) do
          clients(:no_auth, :server => :remote).post.get(public_post[:id])
        end

        private_post = get(:status_post)
        expect_response(:tent, :schema => :error, :status => 404) do
          clients(:no_auth, :server => :remote).post.get(private_post[:id])
        end
      end

      # - licenses
      # - mentions
      # - views
      describe "PUT /posts/:id (when authorized via app)", :depends_on => create_post do
        auth_details = get(:full_authorization_details)

        status_post = get(:status_post)
        status_data = status_post.merge(JSONGenerator.generate(:post, :status))
        expect_response(:tent, :schema => :post_status, :status => 200, :properties => status_data.merge(:published_at => status_post[:published_at])) do
          clients(:custom, auth_details.merge(:server => :remote)).post.update(status_post[:id], status_data)
        end

        custom_post = get(:custom_post)
        custom_data = custom_post.merge(JSONGenerator.generate(:post, :custom))
        attachments_data, attachments_embeded = JSONGenerator.generate(:post, :attachments, 4)
        expect_response(:tent, :schema => :post, :status => 200, :properties => custom_data.merge(:attachments => attachments_embeded, :published_at => custom_post[:published_at])) do
          clients(:custom, auth_details.merge(:server => :remote)).post.update(custom_post[:id], custom_data, :attachments => attachments_data)
        end
      end

      # - licenses
      # - mentions
      # - views
      # 404 if post type not authorized
      describe "PUT /posts/:id (when authorized via app for specific post type)", :depends_on => create_post do
        auth_details = get(:limited_status_authorization_details)

        status_post = get(:status_post)
        status_data = status_post.merge(JSONGenerator.generate(:post, :status))
        expect_response(:tent, :schema => :post_status, :status => 200, :properties => status_data.merge(:published_at => status_post[:published_at])) do
          clients(:custom, auth_details.merge(:server => :remote)).post.update(status_post[:id], status_data)
        end

        custom_post = get(:custom_post)
        custom_data = custom_post.merge(JSONGenerator.generate(:post, :custom))
        expect_response(:tent, :schema => :error, :status => 404) do
          clients(:custom, auth_details.merge(:server => :remote)).post.update(custom_post[:id], custom_data)
        end
      end

      # 403
      describe "PUT /posts/:id (when authorized via app only for read_posts)", :depends_on => create_post do
        auth_details = get(:full_read_authorization_details)

        status_post = get(:status_post)
        status_data = status_post.merge(JSONGenerator.generate(:post, :status))
        expect_response(:tent, :schema => :error, :status => 403) do
          clients(:custom, auth_details.merge(:server => :remote)).post.update(status_post[:id], status_data)
        end
      end

      # 403
      describe "PUT /posts/:id (when not authorized)", :depends_on => create_post do
        status_post = get(:status_post)
        status_data = status_post.merge(JSONGenerator.generate(:post, :status))
        expect_response(:tent, :schema => :error, :status => 403) do
          clients(:not_auth, :server => :remote).post.update(status_post[:id], status_data)
        end
      end

      describe "DELETE /posts/:id (when authorized via app)", :depends_on => create_post do
        auth_details = get(:full_authorization_details)

        status_post = get(:status_post)
        expect_response(:status => 200) do
          clients(:custom, auth_details.merge(:server => :remote)).post.delete(status_post[:id])
        end
      end

      describe "DELETE /posts/:id (when authorized via app for specific post type)", :depends_on => create_post do
        auth_details = get(:limited_photo_authorization_details)

        status_post = get(:status_post)
        expect_response(:tent, :schema => :error, :status => 404) do
          clients(:custom, auth_details.merge(:server => :remote)).post.delete(status_post[:id])
        end

        essay_post = get(:essay_post)
        expect_response(:tent, :schema => :error, :status => 404) do
          clients(:custom, auth_details.merge(:server => :remote)).post.delete(essay_post[:id])
        end

        photo_post = get(:photo_post)
        expect_response(:status => 200) do
          clients(:custom, auth_details.merge(:server => :remote)).post.delete(photo_post[:id])
        end
      end

      # 403
      describe "DELETE /posts/:id (when authorized via app only for read_posts)", :depends_on => create_post do
        auth_details = get(:full_read_authorization_details)

        custom_post = get(:custom_post)
        expect_response(:tent, :schema => :error, :status => 403) do
          clients(:custom, auth_details.merge(:server => :remote)).post.delete(custom_post[:id])
        end

        status_post = get(:status_post)
        expect_response(:tent, :schema => :error, :status => 403) do
          clients(:custom, auth_details.merge(:server => :remote)).post.delete(status_post[:id])
        end
      end

      # 403
      describe "DELETE /posts/:id (when not authorized)", :depends_on => create_post do
        custom_post = get(:custom_post)
        expect_response(:tent, :schema => :error, :status => 403) do
          clients(:no_auth, :server => :remote).post.delete(custom_post[:id])
        end

        status_post = get(:status_post)
        expect_response(:tent, :schema => :error, :status => 403) do
          clients(:no_auth, :server => :remote).post.delete(status_post[:id])
        end
      end

      # - validate params
      #   - before_id
      #   - before_id_entity (test with posts from another entity)
      #   - since_id
      #   - since_id_entity (test with posts from another entity)
      #   - before_time
      #   - since_time
      #   - until_id
      #   - limit
      #   - post_types
      #   - mentioned_entity
      #   - mentioned_post
      # - validate with private, public, original, non orginal posts, and combinations of these
      describe "GET /posts (when authorized via app)", :depends_on => create_authorizations do
        auth_details = get(:full_authorization_details)

        posts = 7.times.map { clients(:app, :server => :remote).post.create(JSONGenerator.generate(:post, :import, :status, :permissions => { :public => false }, :entity => TentValidator.remote_entity)).body }.reverse.each { |post| post.merge!('permissions' => { 'public' => false }) }
        validate_params(:before_id, :since_id, :limit, :resources => posts).
          expect_response(:tent, :schema => :post_status, :list => true, :status => 200) do |params|
            clients(:custom, auth_details.merge(:server => :remote)).post.list(params.merge(:post_types => posts.first[:type]))
          end

        validate_params(:before_time, :since_time, :limit, :resources => posts).
          expect_response(:tent, :schema => :post_status, :list => true, :status => 200) do |params|
            clients(:custom, auth_details.merge(:server => :remote)).post.list(params.merge(:post_types => posts.first[:type]))
          end

        # TODO: import 7 public original posts
        # TODO: validate params

        # TODO: import a mix of private and public original posts
        # TODO: validate params

        # TODO: import 7 private non-original posts
        # TODO: validate params

        # TODO: import 7 public non-original posts
        # TODO: validate params

        # TODO: import a mix of private and public non-original posts
        # TODO: validate params

        # TODO: import a mix of private and public original and non-original posts
        # TODO: validate params
      end

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
