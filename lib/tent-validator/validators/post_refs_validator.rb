module TentValidator
  class PostRefsValidator < TentValidator::Spec
    SetupFailure = Class.new(StandardError)

    require 'tent-validator/validators/support/post_generators'
    class << self
      include Support::PostGenerators
    end
    include Support::PostGenerators

    create_post = lambda do |opts|
      data = generate_status_post(opts[:public])

      if opts[:refs]
        data[:refs] = opts[:refs]
      end

      res = clients(:app).post.create(data)

      data.delete(:permissions) if opts[:public] == true
      if data[:refs]
        data[:refs].each { |ref|
          ref.delete(:entity) if ref[:entity] == TentValidator.remote_entity_uri
        }
      end

      if TentValidator.remote_auth_details
        res_validation = ApiValidator::Json.new(data).validate(res)
        raise SetupFailure.new("Failed to create post! #{res.status}\n\t#{Yajl::Encoder.encode(res_validation[:diff])}\n\t#{res.body}") unless res_validation[:valid]
      end

      TentD::Utils::Hash.symbolize_keys(res.body)
    end

    describe "POST new_post with refs" do
      setup do
        reffed_post = create_post.call(:public => true)
        set(:reffed_post, reffed_post)
      end

      context "" do
        expect_response(:status => 200, :schema => :post) do
          reffed_post = get(:reffed_post)
          data = generate_status_post.merge(
            :refs => [
              { :entity => reffed_post[:entity], :type => reffed_post[:type], :post => reffed_post[:id] }
            ]
          )

          expected_data = TentD::Utils::Hash.deep_dup(data)
          expected_data[:refs][0].delete(:entity)
          expected_data.delete(:permissions)

          expect_properties(expected_data)

          clients(:app).post.create(data)
        end
      end
    end

    describe "PUT post with refs" do
      setup do
        post = create_post.call(:public => true)
        set(:post, post)
      end

      context "" do
        expect_response(:status => 200, :schema => :post) do
          post = get(:post)

          data = generate_status_post
          data[:refs] = [
            { :entity => "http://fictitious.example.org", :type => "https://tent.io/types/status/v0#reply", :post => "fictitious-post-identifier" }
          ]

          expected_data = TentD::Utils::Hash.deep_dup(data)
          expected_data.delete(:permissions)

          expect_properties(expected_data)

          clients(:app).post.update(post[:entity], post[:id], data)
        end
      end
    end

    describe "GET post with refs" do
      setup do
        posts = 3.times.map { create_post.call(:public => true) }
        post = create_post.call(
          :public => true,
          :refs => posts.map { |p|
            { :entity => p[:entity], :type => p[:type], :post => p[:id] }
          }
        )

        set(:posts, posts)
        set(:post, post)
      end

      expect_response(:status => 200, :schema => :data) do
        post = get(:post)
        posts = get(:posts)

        expect_properties(:refs => ApiValidator::UnorderedList.new(posts))
        expect_property_length('/refs', 3)
        expect_properties(:post => post)

        clients(:app).post.get(post[:entity], post[:id], :'max-refs' => 3)
      end
    end

    describe "GET posts_feed with refs" do
      setup do
        post_1_reffed_posts = 3.times.map { create_post.call(:public => true) }
        post_2_reffed_posts = 2.times.map { create_post.call(:public => true) }
        post_4_reffed_posts = [ create_post.call(:public => true) ]

        post_1 = create_post.call(
          :public => true,
          :refs => post_1_reffed_posts.map { |p|
            { :entity => p[:entity], :type => p[:type], :post => p[:id] }
          }
        )

        post_2 = create_post.call(
          :public => true,
          :refs => post_2_reffed_posts.map { |p|
            { :entity => p[:entity], :type => p[:type], :post => p[:id] }
          }
        )

        post_3 = create_post.call(
          :public => true,
        )

        post_4 = create_post.call(
          :public => true,
          :refs => (post_1_reffed_posts + post_4_reffed_posts).map { |p|
            { :entity => p[:entity], :type => p[:type], :post => p[:id] }
          }
        )

        set(:reffed_posts, post_1_reffed_posts + post_2_reffed_posts + post_4_reffed_posts)
        set(:posts, [post_1, post_2, post_3, post_4])
      end

      expect_response(:status => 200, :schema => :data) do
        reffed_posts = get(:reffed_posts)
        posts = get(:posts)

        expect_properties(:refs => ApiValidator::UnorderedList.new(reffed_posts))
        expect_property_length('/refs', reffed_posts.size)
        expect_properties(:posts => posts.reverse)

        clients(:app).post.list(:'max-refs' => 4, :limit => posts.size)
      end
    end
  end

  TentValidator.validators << PostRefsValidator
end
