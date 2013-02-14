require 'tentd/core_ext/hash/slice'
require 'faker'

module TentValidator
  module Spec
    class FollowersValidation < Validation
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
        authorization = JSONGenerator.generate(:app_authorization, :with_auth, :scopes => %w[ read_followers write_followers read_groups ])
        set(:full_authorization_with_groups, authorization)
        set(:full_authorization_with_groups_details, authorization.slice(:mac_key_id, :mac_key, :mac_algorithm))
        expect_response(:tent, :schema => :app_authorization, :status => 200) do
          clients(:app, :server => :remote).app.authorization.create(app[:id], authorization)
        end

        # Create fully authorized authorization (without read_groups)
        authorization2 = JSONGenerator.generate(:app_authorization, :with_auth, :scopes => %w[ read_followers write_followers ])
        set(:full_authorization, authorization2)
        set(:full_authorization_details, authorization2.slice(:mac_key_id, :mac_key, :mac_algorithm))
        expect_response(:tent, :schema => :app_authorization, :status => 200) do
          clients(:app, :server => :remote).app.authorization.create(app[:id], authorization2)
        end

        # Create fully unauthorized authorization
        authorization3 = JSONGenerator.generate(:app_authorization, :with_auth, :scopes => %w[ read_followings write_followings ])
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

      describe "OPTIONS /followers" do
        expect_response :tent_cors, :status => 200 do
          clients(:no_auth, :server => :remote).http.options("followers")
        end
      end

      describe "OPTIONS /followers/(:id|:entity)" do
        expect_response :tent_cors, :status => 200 do
          clients(:no_auth, :server => :remote).http.options("followers/abc")
        end
      end

      import = describe "POST /followers (when write_secrets and write_followers authorized)" do
        data = JSONGenerator.generate(:follower, :with_auth)
        expected_data = data.dup
        %w[ mac_key_id mac_key mac_algorithm ].each { |k| expected_data.delete(k) || expected_data.delete(k.to_sym) }

        expect_response(:tent, :schema => :follow, :status => 200, :properties => expected_data) do
          clients(:app, :server => :remote).follower.create(data)
        end

        # ensure mac auth got imported
        expect_response(:tent, :schema => :follow, :status => 200, :properties => data) do
          clients(:app, :server => :remote).follower.get(data[:id], :secrets => true)
        end
      end

      # create following on local server which will send request to create a follower on remote server
      follow = describe "POST /followers (without authorization)", :depends_on => create_authorizations do
        user = TentD::Model::User.generate
        set(:user_id, user.id)
        follower_id = nil
        expect_response(:tent, :schema => :following, :status => 200, :properties_present => [:remote_id], :properties => { :permissions => { :public => false } }) do
          clients(:app, :server => :local, :user => user.id).following.create(TentValidator.remote_entity, { :permissions => { :public => false } }, :secrets => true)
        end.after do |result|
          if result.response.success?
            follower_id = result.response.body['remote_id']
            set(:follower_id, follower_id)
            set(:follower_entity, user.entity)
            set(:following_id, result.response.body['id'])
            set(:following_mac, result.response.body.slice('mac_key_id', 'mac_key', 'mac_algorithm').inject({}) { |m, (k,v)| m[k.to_sym] = v; m })
          end
        end

        auth_details = get(:full_authorization_details)
        expect_response(:tent, :schema => :follow, :status => 200, :properties => { :entity => user.entity, :permissions => { :public => false }}) do
          clients(:custom, auth_details.merge(:server => :remote)).follower.get(follower_id)
        end
      end

      describe "GET /followers/:id (when authorized)", :depends_on => follow do
        auth_details = get(:full_authorization_details)
        expect_response(:tent, :schema => :follow, :status => 200, :properties => { :entity => get(:follower_entity), :id => get(:follower_id), :permissions => { :public => false } }) do
          clients(:custom, auth_details.merge(:server => :remote)).follower.get(get(:follower_id))
        end
      end

      describe "GET /followers/:id (when read_groups authorized)", :depends_on => create_authorizations do
        follower = create_resource(:follower, { :server => :remote, :schema => :follow }, :with_auth, :groups => [get(:group)])

        auth_details = get(:full_authorization_with_groups_details)
        expect_response(:tent, :schema => :follow, :status => 200, :properties => follower.merge('groups' => [{ :id => get(:group)['id'] }])) do
          clients(:custom, auth_details.merge(:server => :remote)).follower.get(follower['id'])
        end
      end

      describe "GET /followers/:id (when unauthorized)", :depends_on => follow do
        auth_details = get(:explicit_unauthorization_details)
        expect_response(:tent, :schema => :error, :status => 404, :properties_present => [:error]) do
          clients(:custom, auth_details.merge(:server => :remote)).follower.get(get(:follower_id))
        end
      end

      describe "GET /followers/:entity (when authorized)", :depends_on => follow do
        auth_details = get(:full_authorization_details)
        expect_response(:tent, :schema => :follow, :status => 200, :properties => { :entity => get(:follower_entity), :id => get(:follower_id), :permissions => { :public => false } }) do
          clients(:custom, auth_details.merge(:server => :remote)).follower.get(get(:follower_entity))
        end
      end

      describe "GET /followers/:entity (when read_groups authorized)", :depends_on => follow do
        follower = create_resource(:follower, { :server => :remote, :schema => :follow }, :with_auth, :groups => [get(:group)])

        auth_details = get(:full_authorization_with_groups_details)
        expect_response(:tent, :schema => :follow, :status => 200, :properties => follower.merge('groups' => [{ :id => get(:group)['id'] }])) do
          clients(:custom, auth_details.merge(:server => :remote)).follower.get(follower['entity'])
        end
      end

      describe "GET /followers/:entity (when unauthorized)", :depends_on => follow do
        auth_details = get(:explicit_unauthorization_details)
        expect_response(:tent, :schema => :error, :status => 404, :properties_present => [:error]) do
          clients(:custom, auth_details.merge(:server => :remote)).follower.get(get(:follower_entity))
        end
      end

      describe "HEAD /followers (with authorization)"

      describe "HEAD /followers (without authorization)"

      # GET /followings
      #
      # - with all param combinations
      #   - before_id
      #   - since_id
      #   - limit

      describe "GET /followers (with authorization)"

      describe "GET /followers (with authorization when read_groups authorized)"

      describe "GET /followers (without authorization)"

      describe "PUT /followers/:id (when authorized via app with read_groups)", :depends_on => follow do
        auth_details = get(:full_authorization_with_groups_details)
        data = {
          :groups => [get(:group)],
          :types => %w[ https://tent.io/types/post/photo/v0.1.0 ],
          :licenses => [Faker::Internet.url, Faker::Internet.url]
        }
        expect_response(:tent, :schema => :follow, :status => 200, :properties => data.merge(:id => get(:follower_id), :groups => [get(:group).slice('id')])) do
          clients(:custom, auth_details.merge(:server => :remote)).follower.update(get(:follower_id), data)
        end
      end

      describe "PUT /followers/:id (when authorized via identity)", :depends_on => follow do
        data = {
          :types => %w[ https://tent.io/types/post/essay/v0.1.0 ],
          :licenses => [Faker::Internet.url, Faker::Internet.url]
        }
        expect_response(:tent, :schema => :follow, :status => 200, :properties => data.merge(:id => get(:follower_id))) do
          clients(:custom, get(:following_mac).merge(:server => :remote)).follower.update(get(:follower_id), data)
        end

        expect_response(:tent, :schema => :follow, :status => 200, :properties => data.merge(:id => get(:follower_id))) do
          clients(:app, :server => :remote).follower.get(get(:follower_id))
        end
      end

      describe "PUT /followers/:id (when unauthorized)", :depends_on => follow do
        auth_details = get(:explicit_unauthorization_details)
        data = {
          :types => %w[ https://tent.io/types/post/bogus/v0.1.0 ],
          :licenses => [Faker::Internet.url, Faker::Internet.url]
        }

        expect_response(:tent, :schema => :error, :status => 403) do
          clients(:custom, auth_details.merge(:server => :remote)).follower.update(get(:follower_id), data)
        end
      end

      describe "DELETE /followers/:id (when unauthorized)", :depends_on => follow do
        auth_details = get(:explicit_unauthorization_details)
        expect_response(:tent, :schema => :error, :status => 403) do
          clients(:custom, auth_details.merge(:server => :remote)).follower.delete(get(:follower_id))
        end
      end

      describe "DELETE /followers/:id (when authorized)", :depends_on => follow do
        auth_details = get(:full_authorization_details)
        expect_response(:status => 200) do
          clients(:custom, auth_details.merge(:server => :remote)).follower.delete(get(:follower_id))
        end

        expect_response(:tent, :schema => :error, :status => 404) do
          clients(:custom, auth_details.merge(:server => :remote)).follower.get(get(:follower_id))
        end
      end
    end
  end
end
