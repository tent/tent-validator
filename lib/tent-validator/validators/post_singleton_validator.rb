module TentValidator
  class PostSingletonValidator < TentValidator::Spec
    SetupFailure = Class.new(StandardError)

    require 'tent-validator/validators/support/post_generators'
    class << self
      include Support::PostGenerators
    end
    include Support::PostGenerators

    require 'tent-validator/validators/support/app_post_generators'
    include Support::AppPostGenerators

    require 'tent-validator/validators/support/oauth'
    include Support::OAuth

    create_post = lambda do |opts|
      data = generate_status_post(opts[:public])

      if opts[:mentions]
        data[:mentions] = opts[:mentions]
      end

      if opts[:type]
        data[:type] = opts[:type]
      end

      res = clients(:app).post.create(data)

      data.delete(:permissions) if opts[:public] == true

      if data[:mentions]
        data[:mentions].each do |m|
          m.delete(:entity) if m[:entity] == TentValidator.remote_entity_uri
        end
      end

      res_validation = ApiValidator::Json.new(:post => data).validate(res)
      raise SetupFailure.new("Failed to create post with attachments! #{res.status}\n\t#{Yajl::Encoder.encode(res_validation[:diff])}\n\t#{res.body}") unless res_validation[:valid]

      TentD::Utils::Hash.symbolize_keys(res.body['post'])
    end

    describe "GET post" do
      shared_example :get_post do
        expect_response(:status => 200, :schema => :data) do
          expect_schema(:post, '/post')

          post = get(:post).dup

          expect_properties(:post => post)
          expect_properties(:post => { :permissions => property_absent }) unless post.has_key?(:permissions)

          get(:client).post.get(post[:entity], post[:id])
        end
      end

      context "when public post" do
        setup do
          set(:post, create_post.call(:public => true))
        end

        context "without auth" do
          setup do
            set(:client, clients(:no_auth))
          end

          expect_response(:status => 200, :schema => :data) do
            expect_schema(:post, '/post')

            post = get(:post).dup
            (post[:app] ||= {})[:id] = property_absent
            post[:received_at] = property_absent
            post[:version][:received_at]

            expect_properties(:post => post)
            expect_properties(:post => { :permissions => property_absent }) unless post.has_key?(:permissions)

            get(:client).post.get(post[:entity], post[:id])
          end
        end

        context "with auth" do
          context "when post type not authorized" do
            authenticate_with_permissions(:read_post_types => [])

            behaves_as(:get_post)
          end

          context "when limited authorization" do
            authenticate_with_permissions(:read_post_types => %w(https://tent.io/types/status/v0#))

            behaves_as(:get_post)
          end

          context "when full authorization" do
            setup do
              set(:client, clients(:app))
            end

            behaves_as(:get_post)
          end
        end
      end

      context "when private post" do
        setup do
          set(:post, create_post.call(:public => false))
        end

        context "without auth" do
          expect_response(:status => 404, :schema => :error) do
            post = get(:post)
            clients(:no_auth).post.get(post[:entity], post[:id])
          end
        end

        context "with auth" do
          context "when post type not authorized" do
            authenticate_with_permissions(:read_post_types => [])

            expect_response(:status => 404, :schema => :error) do
              post = get(:post)
              get(:client).post.get(post[:entity], post[:id])
            end
          end

          context "when limited authorization" do
            authenticate_with_permissions(:read_post_types => %w(https://tent.io/types/status/v0#))

            behaves_as(:get_post)
          end

          context "when full authorization" do
            setup do
              set(:client, clients(:app))
            end

            behaves_as(:get_post)
          end
        end
      end
    end

    describe "GET post with mentions accept header" do
      shared_example :get_all_mentions do
        expect_response(:status => 200, :schema => :data) do
          expect_properties(:mentions => get(:posts).reverse.map { |post|
            m = { :post => post[:id], :type => post[:type] }
            m[:entity] = post[:entity] unless post[:entity] == get(:post)[:entity]
            m[:public] = false if post[:permissions]
            m
          })

          expect_headers('Content-Type' => %(application/vnd.tent.post-mentions.v0+json))

          post = get(:post)
          get(:client).post.mentions(post[:entity], post[:id])
        end
      end

      shared_example :get_public_mentions do
        expect_response(:status => 200, :schema => :data) do
          expect_properties(:mentions => get(:public_posts).reverse.map { |post|
            m = { :post => post[:id], :type => post[:type] }
            m[:entity] = post[:entity] unless post[:entity] == get(:post)[:entity]
            m
          })

          expect_headers('Content-Type' => %(application/vnd.tent.post-mentions.v0+json))

          post = get(:post)
          get(:client).post.mentions(post[:entity], post[:id])
        end
      end

      context "when public" do
        setup do
          post = create_post.call(:public => true)

          opts = {
            :mentions => [{ :entity => post[:entity], :type => post[:type], :post => post[:id] }]
          }

          post_1 = create_post.call(opts.merge(:public => true))
          post_2 = create_post.call(opts.merge(:public => false, :type => %(https://tent.io/types/status/v0#reply)))
          post_3 = create_post.call(opts.merge(:public => true))

          set(:posts, [post_1, post_2, post_3])
          set(:public_posts, [post_1, post_3])
          set(:private_posts, [post_2])

          set(:post, post)
        end

        context "without auth" do
          setup do
            set(:client, clients(:no_auth))
          end

          behaves_as(:get_public_mentions)
        end

        context "with auth" do
          context "when limited authorization" do
            authenticate_with_permissions(:read_post_types => %w(https://tent.io/types/status/v0#))

            behaves_as(:get_all_mentions)
          end

          context "when full authorization" do
            setup do
              set(:client, clients(:app))
            end

            behaves_as(:get_all_mentions)
          end
        end
      end

      context "when private" do
        setup do
          post = create_post.call(:public => false)

          opts = {
            :mentions => [{ :entity => post[:entity], :type => post[:type], :post => post[:id] }]
          }

          post_1 = create_post.call(opts.merge(:public => true))
          post_2 = create_post.call(opts.merge(:public => false, :type => %(https://tent.io/types/status/v0#reply)))
          post_3 = create_post.call(opts.merge(:public => true))

          set(:posts, [post_1, post_2, post_3])
          set(:public_posts, [post_1, post_3])
          set(:private_posts, [post_2])

          set(:post, post)
        end

        context "without auth" do
          expect_response(:status => 404, :schema => :error) do
            post = get(:post)
            clients(:no_auth).post.mentions(post[:entity], post[:id])
          end
        end

        context "with auth" do
          context "when limited authorization" do
            authenticate_with_permissions(:read_post_types => %w(https://tent.io/types/status/v0#))

            behaves_as(:get_all_mentions)
          end

          context "when full authorization" do
            setup do
              set(:client, clients(:app))
            end

            behaves_as(:get_all_mentions)
          end
        end
      end
    end

  end

  TentValidator.validators << PostSingletonValidator
end
