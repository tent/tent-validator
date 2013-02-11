require 'tentd/core_ext/hash/slice'
require 'faker'

module TentValidator
  module Spec
    class FollowingsValidation < Validation
      create_authorizations = describe "Create authorizations" do
        # Create app
        app = JSONGenerator.generate(:app, :with_auth)
        expect_response(:tent, :schema => :app, :status => 200, :properties => app) do
          clients(:app, :server => :remote).app.create(app)
        end.after do |result|
          if result.response.success?
            set(:app, app)
          end
        end

        # Create fully authorized authorization (with read_groups)
        authorization = JSONGenerator.generate(:app_authorization, :with_auth, :scopes => %w[ read_followings write_followings read_groups ])
        set(:full_authorization_with_groups, authorization)
        set(:full_authorization_with_groups_details, authorization.slice(:mac_key_id, :mac_key, :mac_algorithm))
        expect_response(:tent, :schema => :app_authorization, :status => 200) do
          clients(:app, :server => :remote).app.authorization.create(app[:id], authorization)
        end

        # Create fully authorized authorization (without read_groups)
        authorization2 = JSONGenerator.generate(:app_authorization, :with_auth, :scopes => %w[ read_followings write_followings ])
        set(:full_authorization, authorization2)
        set(:full_authorization_details, authorization2.slice(:mac_key_id, :mac_key, :mac_algorithm))
        expect_response(:tent, :schema => :app_authorization, :status => 200) do
          clients(:app, :server => :remote).app.authorization.create(app[:id], authorization2)
        end

        # Create fully unauthorized authorization
        authorization3 = JSONGenerator.generate(:app_authorization, :with_auth, :scopes => %w[ read_followers write_followers ])
        set(:explicit_unauthorization, authorization3)
        set(:explicit_unauthorization_details, authorization3.slice(:mac_key_id, :mac_key, :mac_algorithm))
        expect_response(:tent, :schema => :app_authorization, :status => 200) do
          clients(:app, :server => :remote).app.authorization.create(app[:id], authorization3)
        end

        # Create group
        group_data = JSONGenerator.generate(:group, :simple)
        expect_response(:tent, :schema => :group, :status => 200, :properties => group_data) do
          clients(:app, :server => :remote).group.create(group_data)
        end.after do |result|
          if result.response.success?
            set(:group, result.response.body)
          end
        end
      end

      describe "OPTIONS /followings" do
        expect_response :tent_cors, :status => 200 do
          clients(:no_auth, :server => :remote).http.options("followings")
        end
      end

      describe "OPTIONS /followings/(:id|:entity)" do
        expect_response :tent_cors, :status => 200 do
          clients(:no_auth, :server => :remote).http.options("followings/abc")
        end
      end

      describe "OPTIONS /followings/:id/*" do
        expect_response :tent_cors, :status => 200 do
          clients(:no_auth, :server => :remote).http.options("followings/abc/cde")
        end
      end

      follow = describe "POST /followings (when authorized)", :depends_on => create_authorizations do
        auth_details = get(:full_authorization_details)
        user = TentD::Model::User.generate
        set(:user_id, user.id)
        expect_response(:tent, :schema => :following, :status => 200, :properties => { :entity => user.entity }) do
          clients(:custom, auth_details.merge(:server => :remote)).following.create(user.entity)
        end.after do |result|
          if result.response.success?
            set(:following, result.response.body)
          end
        end

        expect_response(:tent, :schema => :follow, :status => 200) do
          clients(:app, :server => :local, :user => user.id).follower.get((get(:following) || {})["remote_id"])
        end
      end

      follow_explicit = describe "POST /followings (when authorized)", :depends_on => create_authorizations do
        auth_details = get(:full_authorization_with_groups_details)
        user = TentD::Model::User.generate
        set(:user_id, user.id)
        group = get(:group)
        data = {
          :entity => user.entity,
          :types => %w[ https://tent.io/types/post/status/v0.1.0 ],
          :licenses => [Faker::Internet.url],
          :groups => [group],
          :permissions => {
            :public => false,
          }
        }
        expected_data = data.dup
        expected_data[:groups] = [{ :id => group['id'] }]
        expect_response(:tent, :schema => :following, :status => 200, :properties => expected_data) do
          clients(:custom, auth_details.merge(:server => :remote)).following.create(data[:entity], data)
        end.after do |result|
          if result.response.success?
            set(:following, result.response.body)
          end
        end

        expect_response(:tent, :schema => :follow, :status => 200, :data => data.slice(:entity, :licenses, :types).merge(:public => false)) do
          clients(:app, :server => :local, :user => user.id).follower.get((get(:following) || {})["remote_id"])
        end
      end

      import = describe "POST /followings (when write_secrets authorized)", :depends_on => create_authorizations do
        core_profile = JSONGenerator.generate(:profile, :core)
        data = JSONGenerator.generate(:following, :with_auth, :groups => [{ :id => get(:group)['id'] }], :entity => core_profile["entity"], :profile => { TentD::Model::ProfileInfo::TENT_PROFILE_TYPE_URI => core_profile })
        expected_data = data.dup
        [:mac_key_id, :mac_key, :mac_algorithm].each { |key| expected_data.delete(key) }
        expect_response(:tent, :schema => :following, :status => 200, :properties => expected_data) do
          clients(:app, :server => :remote).following.create(data[:entity], data)
        end
      end

      describe "POST /followings (when authorized and already following)", :depends_on => follow do
        auth_details = get(:full_authorization_details)
        user = TentD::Model::User.first(:id => get(:user_id))
        expect_response(:tent, :schema => :error, :status => 409) do
          clients(:custom, auth_details.merge(:server => :remote)).following.create(user.entity)
        end
      end

      describe "POST /followings (when unauthorized)", :depends_on => create_authorizations do
        auth_details = get(:explicit_unauthorization_details)
        user = TentD::Model::User.generate
        expect_response(:tent, :schema => :error, :status => 403) do
          clients(:custom, auth_details.merge(:server => :remote)).following.create(user.entity)
        end
      end

      describe "PUT /followings/:id (when authorized and has read_groups scope)", :depends_on => follow do
        auth_details = get(:full_authorization_with_groups_details)
        following = get(:following) || {}
        data = { "permissions" => { "public" => false }, "groups" => [get(:group)] }
        expected_data = data.dup
        expected_data["groups"] = [get(:group).slice("id")]
        expect_response(:tent, :schema => :following, :status => 200, :properties => expected_data) do
          clients(:custom, auth_details.merge(:server => :remote)).following.update(following['id'], data)
        end
      end

      update_follow = describe "PUT /followings/:id (when authorized)", :depends_on => follow do
        auth_details = get(:full_authorization_details)
        following = get(:following) || {}
        data = { "permissions" => { "public" => false }, "groups" => [get(:group)] }
        expected_data = data.dup
        expected_data.delete("groups")
        expect_response(:tent, :schema => :following, :status => 200, :properties => expected_data, :properties_absent => [:groups]) do
          clients(:custom, auth_details.merge(:server => :remote)).following.update(following['id'], data)
        end.after do |result|
          if result.response.success?
            set(:following, result.response.body)
          end
        end
      end

      describe "PUT /followings/:id (when authorized and does not exist)", :depends_on => follow do
        auth_details = get(:full_authorization_details)
        data = { "permissions" => { "public" => false }, "groups" => [get(:group)] }
        expect_response(:tent, :schema => :error, :status => 404) do
          clients(:custom, auth_details.merge(:server => :remote)).following.update('bugus-id', data)
        end
      end

      describe "PUT /followings/:id (when unauthorized)", :depends_on => follow do
        auth_details = get(:explicit_unauthorization_details)
        following = get(:following) || {}
        data = { "permissions" => { "public" => false }, "groups" => [get(:group)] }
        expect_response(:tent, :schema => :error, :status => 403) do
          clients(:custom, auth_details.merge(:server => :remote)).following.update(following['id'], data)
        end
      end

      describe "GET /followings/:id (when authorized and has read_groups scope)", :depends_on => update_follow do
        auth_details = get(:full_authorization_with_groups_details)
        following = get(:following) || {}
        expect_response(:tent, :schema => :following, :status => 200, :properties => following, :properties_absent => [:mac_key, :mac_key_id, :mac_algorithm]) do
          clients(:custom, auth_details.merge(:server => :remote)).following.get(following['id'])
        end
      end

      describe "GET /followings/:id (when authorized without secrest param and has read_secrets scope)", :depends_on => update_follow do
        following = get(:following) || {}
        expect_response(:tent, :schema => :following, :status => 200, :properties => following, :properties_absent => [:mac_key, :mac_key_id, :mac_algorithm]) do
          clients(:app, :server => :remote).following.get(following['id'])
        end
      end

      describe "GET /followings/:id (when authorized with secrest param and has read_secrets scope)", :depends_on => update_follow do
        following = get(:following) || {}
        expect_response(:tent, :schema => :following, :status => 200, :properties => following, :properties_present => [:mac_key_id, :mac_key, :mac_algorithm]) do
          clients(:app, :server => :remote).following.get(following['id'], :secrets => true)
        end
      end

      describe "GET /followings/:id (when authorized)", :depends_on => update_follow do
        auth_details = get(:full_authorization_details)
        following = get(:following) || {}
        expect_response(:tent, :schema => :following, :status => 200, :properties => following, :properties_absent => [:groups, :mac_key, :mac_key_id, :mac_algorithm]) do
          clients(:custom, auth_details.merge(:server => :remote)).following.get(following['id'])
        end
      end

      describe "GET /followings/(:id|:entity) (when authorized and does not exist)", :depends_on => update_follow do
        auth_details = get(:full_authorization_details)
        following = get(:following) || {}
        expect_response(:tent, :schema => :error, :status => 404) do
          clients(:custom, auth_details.merge(:server => :remote)).following.get('bogus-id')
        end
      end

      describe "GET /followings/:id (when unauthorized and following private)", :depends_on => update_follow do
        auth_details = get(:explicit_unauthorization_details)
        following = get(:following) || {}
        expect_response(:tent, :schema => :error, :status => 404) do
          clients(:custom, auth_details.merge(:server => :remote)).following.get(following['id'])
        end
      end

      describe "GET /followings/:entity (when authorized and has read_groups scope)", :depends_on => update_follow do
        auth_details = get(:full_authorization_with_groups_details)
        following = get(:following) || {}
        expect_response(:tent, :schema => :following, :status => 200, :properties => following, :properties_absent => [:mac_key, :mac_key_id, :mac_algorithm]) do
          clients(:custom, auth_details.merge(:server => :remote)).following.get(following['entity'])
        end
      end

      describe "GET /followings/:entity (when authorized without secrets param and has read_secrets scope)", :depends_on => update_follow do
        following = get(:following) || {}
        expect_response(:tent, :schema => :following, :status => 200, :properties => following, :properties_absent => [:mac_key, :mac_key_id, :mac_algorithm]) do
          clients(:app, :server => :remote).following.get(following['entity'])
        end
      end

      describe "GET /followings/:entity (when authorized with secrets param and has read_secrets scope)", :depends_on => update_follow do
        following = get(:following) || {}
        expect_response(:tent, :schema => :following, :status => 200, :properties => following, :properties_present => [:mac_key_id, :mac_key, :mac_algorithm]) do
          clients(:app, :server => :remote).following.get(following['entity'], :secrets => true)
        end
      end

      describe "GET /followings/:entity (when authorized)", :depends_on => update_follow do
        auth_details = get(:full_authorization_details)
        following = get(:following) || {}
        expect_response(:tent, :schema => :following, :status => 200, :properties => following, :properties_absent => [:groups, :mac_key, :mac_key_id, :mac_algorithm]) do
          clients(:custom, auth_details.merge(:server => :remote)).following.get(following['entity'])
        end
      end

      describe "GET /followings/:entity (when unauthorized and following private)", :depends_on => update_follow do
        auth_details = get(:explicit_unauthorization_details)
        following = get(:following) || {}
        expect_response(:tent, :schema => :error, :status => 404) do
          clients(:custom, auth_details.merge(:server => :remote)).following.get(following['entity'])
        end
      end

      describe "GET /followings/:id/* (when authorized)", :depends_on => update_follow do
        remote_entity = get(:remote_entity)
        post = JSONGenerator.generate(:post, :status, :permissions => {
          :public => false,
          :entities => { remote_entity => true }
        })
        user = TentD::Model::User.first(:id => get(:user_id))
        expect_response(:tent, :schema => :post_status, :status => 200, :properties => post) do
          clients(:app, :server => :local, :user => get(:user_id)).post.create(post)
        end.after do |result|
          if result.response.success?
            set(:post_id, result.response.body['id'])
          end
        end

        auth_details = get(:full_authorization_details)
        following = get(:following) || {}
        expect_response(:tent, :schema => :post_status, :status => 200, :properties => post.merge(:permissions => { :public => false})) do
          clients(:custom, auth_details.merge(:server => :remote)).following.proxy(following['id']).post.get(get(:post_id))
        end
      end

      describe "GET /followings/:id/* (when unauthorized)", :depends_on => update_follow do
        remote_entity = get(:remote_entity)
        post = JSONGenerator.generate(:post, :status, :permissions => {
          :public => false,
          :entities => { remote_entity => true }
        })
        user = TentD::Model::User.first(:id => get(:user_id))
        expect_response(:tent, :schema => :post_status, :status => 200, :properties => post) do
          clients(:app, :server => :local, :user => get(:user_id)).post.create(post)
        end.after do |result|
          if result.response.success?
            set(:post_id, result.response.body['id'])
          end
        end

        auth_details = get(:explicit_unauthorization_details)
        following = get(:following) || {}
        expect_response(:tent, :schema => :error, :status => 404) do
          clients(:custom, auth_details.merge(:server => :remote)).following.proxy(following['id']).post.get(get(:post_id))
        end
      end

      describe "GET /followings (when authorized and has read_groups scope)", :depends_on => follow do
        auth_details = get(:full_authorization_with_groups_details)
        expect_response(:tent, :schema => :following, :list => true, :status => 200, :properties_present => [:groups], :properties_absent => [:mac_key_id, :mac_key, :mac_algorithm]) do
          clients(:custom, auth_details.merge(:server => :remote)).following.list(:limit => 1)
        end
      end

      describe "GET /followings (when authorized without secrets param and has read_secrets scope)", :depends_on => follow do
        expect_response(:tent, :schema => :following, :list => true, :status => 200, :properties_absent => [:mac_key_id, :mac_key, :mac_algorithm]) do
          clients(:app, :server => :remote).following.list(:limit => 1)
        end
      end

      describe "GET /followings (when authorized with secrets param and has read_secrets scope)", :depends_on => follow do
        expect_response(:tent, :schema => :following, :list => true, :status => 200, :properties_present => [:mac_key_id, :mac_key, :mac_algorithm]) do
          clients(:app, :server => :remote).following.list(:limit => 1, :secrets => true)
        end
      end

      describe "GET /followings (when authorized)", :depends_on => follow do
        auth_details = get(:full_authorization_details)
        expect_response(:tent, :schema => :following, :list => true, :status => 200, :properties_absent => [:groups, :mac_key_id, :mac_key, :mac_algorithm]) do
          clients(:custom, auth_details.merge(:server => :remote)).following.list(:limit => 1)
        end

        # import a few followings
        followings = []
        4.times do
          core_profile = JSONGenerator.generate(:profile, :core)
          data = JSONGenerator.generate(:following, :with_auth, :groups => [{ :id => get(:group)['id'] }], :entity => core_profile["entity"], :profile => { TentD::Model::ProfileInfo::TENT_PROFILE_TYPE_URI => core_profile })
          expected_data = data.dup
          [:mac_key_id, :mac_key, :mac_algorithm, :groups].each { |key| expected_data.delete(key) }
          followings << expected_data
          expect_response(:tent, :schema => :following, :status => 200, :properties => expected_data) do
            clients(:app, :server => :remote).following.create(data[:entity], data)
          end
        end

        # validate before_id param
        expect_response(:tent, :schema => :following, :list => true, :status => 200,
                        :body_excludes => [{ :id => followings.last[:id] }],
                        :body_begins_with => followings.slice(0, followings.size-1).reverse) do
          clients(:custom, auth_details.merge(:server => :remote)).following.list(:before_id => followings.last[:id])
        end

        # validate since_id param
        expect_response(:tent, :schema => :following, :list => true, :status => 200,
                        :body_excludes => [{ :id => followings.first[:id] }],
                        :body_begins_with => followings.slice(1, followings.size).reverse) do
          clients(:custom, auth_details.merge(:server => :remote)).following.list(:since_id => followings.first[:id])
        end

        # validate before_id and since_id params
        expect_response(:tent, :schema => :following, :list => true, :status => 200,
                        :body_excludes => [{ :id => followings.first[:id] }, { :id => followings.last[:id] }],
                        :body_begins_with => followings.slice(1, followings.size-2).reverse, :size => followings.size-2) do
          clients(:custom, auth_details.merge(:server => :remote)).following.list(:since_id => followings.first[:id], :before_id => followings.last[:id])
        end

        # validate with limit param
        expect_response(:tent, :schema => :following, :list => true, :status => 200, :size => 3) do
          clients(:custom, auth_details.merge(:server => :remote)).following.list(:limit => 3)
        end

        # validate with before_id and limit params
        expect_response(:tent, :schema => :following, :list => true, :status => 200,
                        :body_excludes => [{ :id => followings.last[:id] }],
                        :body_begins_with => followings.slice(followings.size-3, followings.size-2).reverse, :size => 2) do
          clients(:custom, auth_details.merge(:server => :remote)).following.list(:before_id => followings.last[:id], :limit => 2)
        end

        # validate since_id and limit params
        expect_response(:tent, :schema => :following, :list => true, :status => 200,
                        :body_excludes => [{ :id => followings.first[:id] }],
                        :body_begins_with => followings.slice(1, 2).reverse, :size => 2) do
          clients(:custom, auth_details.merge(:server => :remote)).following.list(:since_id => followings.first[:id], :limit => 2)
        end

        # validate before_id, since_id, and limit params
        expect_response(:tent, :schema => :following, :list => true, :status => 200,
                        :body_excludes => [{ :id => followings.first[:id] }, { :id => followings.last[:id] }],
                        :body_begins_with => followings.slice(1, 2).reverse, :size => 2) do
          clients(:custom, auth_details.merge(:server => :remote)).following.list(:since_id => followings.first[:id], :before_id => followings.last[:id], :limit => 2)
        end
      end

      describe "GET /followings (when unauthorized)", :depends_on => follow do
        auth_details = get(:explicit_unauthorization_details)
        expect_response(:tent, :schema => :following, :list => true, :status => 200, :permissions => { :public => true }) do
          clients(:custom, auth_details.merge(:server => :remote)).following.list
        end
      end

      describe "HEAD /followings (with authorization)", :depends_on => create_authorizations do
        auth_details = get(:full_authorization_details)
        expect_response(:tent_head, :status => 200) do
          clients(:custom, auth_details.merge(:server => :remote)).http.head('followings')
        end
      end

      describe "HEAD /followings (without authorization)" do
        expect_response(:tent_head, :status => 200) do
          clients(:no_auth, :server => :remote).http.head('followings')
        end
      end

      describe "DELETE /followings/:id (when unauthorized)", :depends_on => follow do
        auth_details = get(:explicit_unauthorization_details)
        following = get(:following) || {}
        expect_response(:tent, :schema => :error, :status => 403) do
          clients(:custom, auth_details.merge(:server => :remote)).following.delete(following['id'])
        end

        expect_response(:tent, :schema => :follow, :status => 200) do
          clients(:app, :server => :local, :user => get(:user_id)).follower.get(following["remote_id"])
        end
      end

      describe "DELETE /followings/:id (when authorized)", :depends_on => follow do
        auth_details = get(:full_authorization_details)
        following = get(:following) || {}
        expect_response(:status => 200) do
          clients(:custom, auth_details.merge(:server => :remote)).following.delete(following['id'])
        end

        expect_response(:tent, :schema => :error, :status => 404) do
          clients(:app, :server => :local, :user => get(:user_id)).follower.get(following["remote_id"])
        end
      end
    end
  end
end
