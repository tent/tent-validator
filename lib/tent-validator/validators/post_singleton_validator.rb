module TentValidator
  class PostSingletonValidator < TentValidator::Spec
    require 'tent-validator/validators/support/post_generators'
    class << self
      include Support::PostGenerators
    end
    include Support::PostGenerators

    require 'tent-validator/validators/support/app_post_generators'
    include Support::AppPostGenerators

    require 'tent-validator/validators/support/oauth'
    include Support::OAuth

    require 'tent-validator/validators/support/relationship_importer'
    include Support::RelationshipImporter

    create_post = lambda do |opts|
      data = generate_status_post(opts[:public])

      if opts[:mentions]
        data[:mentions] = opts[:mentions]
      end

      if opts[:type]
        data[:type] = opts[:type]
      end

      if opts[:version]
        data[:version] = TentD::Utils::Hash.deep_dup(opts[:version])
      end

      if opts[:type]
        data[:type] = opts[:type]
      end

      if opts[:put] && ref_post = opts[:post]
        res = clients(:app_auth).post.update(ref_post[:entity], ref_post[:id], data)

        data[:version][:parents].each { |parent| parent.delete(:post) if parent[:post] == ref_post[:id] }

        data[:id] = ref_post[:id]
      else
        res = clients(:app_auth).post.create(data)
      end

      data.delete(:permissions) if opts[:public] == true

      if data[:mentions]
        data[:mentions].each do |m|
          m.delete(:entity) if m[:entity] == TentValidator.remote_entity_uri
        end
      end

      res_validation = ApiValidator::Json.new(:post => data).validate(res)
      raise SetupFailure.new("Failed to create post!", res, res_validation) unless res_validation[:valid]

      if opts[:public] == true
        res_validation = ApiValidator::Json.new(:post => {:permissions => Spec.property_absent}).validate(res)
        raise SetupFailure.new("Failed to create post!", res, res_validation) unless res_validation[:valid]
      end

      TentD::Utils::Hash.symbolize_keys(res.body['post'])
    end

    create_post_version = lambda do |post, opts|
      create_post.call(opts.merge(:put => true, :post => post))
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

            post = TentD::Utils::Hash.deep_dup(get(:post))
            (post[:app] ||= {})[:id] = property_absent
            post[:received_at] = property_absent
            post[:version][:received_at] = property_absent

            expect_properties(:post => post)
            expect_properties(:post => { :permissions => property_absent }) unless post.has_key?(:permissions)

            get(:client).post.get(post[:entity], post[:id])
          end
        end

        context "with auth" do
          context "when post type not authorized" do
            authenticate_with_permissions(:read_types => [])

            behaves_as(:get_post)
          end

          context "when limited authorization" do
            authenticate_with_permissions(:read_types => %w(https://tent.io/types/status/v0#))

            behaves_as(:get_post)
          end

          context "when full authorization" do
            setup do
              set(:client, clients(:app_auth))
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
            authenticate_with_permissions(:read_types => [])

            expect_response(:status => 404, :schema => :error) do
              post = get(:post)
              get(:client).post.get(post[:entity], post[:id])
            end
          end

          context "when limited authorization" do
            authenticate_with_permissions(:read_types => %w(https://tent.io/types/status/v0#))

            behaves_as(:get_post)
          end

          context "when full authorization" do
            setup do
              set(:client, clients(:app_auth))
            end

            behaves_as(:get_post)
          end
        end
      end
    end

    describe "DELETE post" do
      shared_example :get_post do
        expect_response(:status => 200, :schema => :data) do
          post = get(:post)
          get(:client).post.get(post[:entity], post[:id])
        end
      end

      shared_example :delete_post_with_record do
        expect_response(:status => 200, :schema => :data) do
          post = get(:post)

          expect_properties(:post => {
            :entity => post[:entity],
            :type => "https://tent.io/types/delete/v0#",
            :refs => [{ :post => post[:id] }]
          })

          get(:client).post.delete(post[:entity], post[:id])
        end
      end

      shared_example :delete_post_without_record do
        expect_response(:status => 200) do
          expect_headers('Content-Length' => '0')

          post = get(:post)
          get(:client).post.delete(post[:entity], post[:id]) do |request|
            request.headers['Create-Delete-Post'] = 'false'
          end
        end
      end

      shared_example :unauthorized_delete_post do
        expect_response(:status => 403, :schema => :error) do
          post = get(:post)
          get(:client).post.delete(post[:entity], post[:id])
        end
      end

      shared_example :unauthorized_delete_post_401 do
        expect_response(:status => 401, :schema => :error) do
          post = get(:post)
          get(:client).post.delete(post[:entity], post[:id])
        end
      end

      shared_example :not_found_delete_post do
        expect_response(:status => 404, :schema => :error) do
          post = get(:post)
          get(:client).post.delete(post[:entity], post[:id])
        end
      end

      shared_example :not_found_get_post do
        expect_response(:status => 404, :schema => :error) do
          post = get(:post)
          get(:client).post.get(post[:entity], post[:id])
        end
      end

      context "when public post" do
        context "with authentication" do
          context "when not authorized" do
            authenticate_with_permissions(:write_types => [])

            setup do
              set(:post, create_post.call(:public => true))
              set(:client, clients(:no_auth))
            end

            behaves_as(:get_post)

            behaves_as(:unauthorized_delete_post)

            behaves_as(:get_post)
          end

          context "when limited read-only authorization" do
            authenticate_with_permissions(:read_types => %w(https://tent.io/types/status/v0#))

            setup do
              set(:post, create_post.call(:public => true))
            end

            behaves_as(:get_post)

            behaves_as(:unauthorized_delete_post)

            behaves_as(:get_post)
          end

          context "when full read-only authorization" do
            authenticate_with_permissions(:read_types => %w( all ))

            setup do
              set(:post, create_post.call(:public => true))
            end

            behaves_as(:get_post)

            behaves_as(:unauthorized_delete_post)

            behaves_as(:get_post)
          end

          context "when limited authorization" do
            authenticate_with_permissions(:write_types => %w(https://tent.io/types/status/v0#))

            context "with Create-Delete-Post header set to false" do
              context "when single version" do
                setup do
                  set(:post, create_post.call(:public => true))
                end

                behaves_as(:get_post)

                behaves_as(:delete_post_without_record)

                behaves_as(:not_found_get_post)
              end

              context "when multiple versions" do
                setup do
                  post = create_post.call(:public => true)
                  create_post_version.call(post, :public => true, :version => {
                    :parents => [{ :version => post[:version][:id], :post => post[:id] }]
                  })
                  set(:post, post)
                end

                behaves_as(:get_post)

                behaves_as(:delete_post_without_record)

                behaves_as(:not_found_get_post)
              end
            end

            context "without Create-Delete-Post header" do
              context "when single version" do
                setup do
                  set(:post, create_post.call(:public => true))
                end

                behaves_as(:get_post)

                behaves_as(:delete_post_with_record)

                behaves_as(:not_found_get_post)
              end

              context "when multiple versions" do
                setup do
                  post = create_post.call(:public => true)
                  create_post_version.call(post, :public => true, :version => {
                    :parents => [{ :version => post[:version][:id], :post => post[:id] }]
                  })
                  set(:post, post)
                end

                behaves_as(:get_post)

                behaves_as(:delete_post_with_record)

                behaves_as(:not_found_get_post)
              end
            end
          end

          context "when full authorization" do
            setup do
              set(:post, create_post.call(:public => true))
              set(:client, clients(:app_auth))
            end

            context "with Create-Delete-Post header set to false" do
              context "when single version" do
                setup do
                  set(:post, create_post.call(:public => true))
                end

                behaves_as(:get_post)

                behaves_as(:delete_post_without_record)

                behaves_as(:not_found_get_post)
              end

              context "when multiple versions" do
                setup do
                  post = create_post.call(:public => true)
                  create_post_version.call(post, :public => true, :version => {
                    :parents => [{ :version => post[:version][:id], :post => post[:id] }]
                  })
                  set(:post, post)
                end

                behaves_as(:get_post)

                behaves_as(:delete_post_without_record)

                behaves_as(:not_found_get_post)
              end
            end

            context "without Create-Delete-Post header" do
              context "when single version" do
                setup do
                  set(:post, create_post.call(:public => true))
                end

                behaves_as(:get_post)

                behaves_as(:delete_post_with_record)

                behaves_as(:not_found_get_post)
              end

              context "when multiple versions" do
                setup do
                  post = create_post.call(:public => true)
                  create_post_version.call(post, :public => true, :version => {
                    :parents => [{ :version => post[:version][:id], :post => post[:id] }]
                  })
                  set(:post, post)
                end

                behaves_as(:get_post)

                behaves_as(:delete_post_with_record)

                behaves_as(:not_found_get_post)
              end
            end
          end
        end

        context "without authentication" do
          setup do
            set(:post, create_post.call(:public => true))
            set(:client, clients(:no_auth))
          end

          behaves_as(:get_post)

          behaves_as(:unauthorized_delete_post_401)

          behaves_as(:get_post)
        end
      end

      context "when private post" do
        context "with authentication" do
          context "when not authorized" do
            authenticate_with_permissions(:write_types => [])

            setup do
              set(:post, create_post.call(:public => false))
            end

            behaves_as(:not_found_get_post)

            behaves_as(:not_found_delete_post)

            behaves_as(:not_found_get_post)
          end

          context "when limited read-only authentication" do
            authenticate_with_permissions(:read_types => %w(https://tent.io/types/status/v0#))

            setup do
              set(:post, create_post.call(:public => false))
            end

            behaves_as(:get_post)

            behaves_as(:unauthorized_delete_post)

            behaves_as(:get_post)
          end

          context "when full read-only authorization" do
            authenticate_with_permissions(:read_types => %w( all ))

            setup do
              set(:post, create_post.call(:public => false))
            end

            behaves_as(:get_post)

            behaves_as(:unauthorized_delete_post)

            behaves_as(:get_post)
          end

          context "when limited authorization" do
            authenticate_with_permissions(:write_types => %w(https://tent.io/types/status/v0#))

            context "without Create-Delete-Post header set" do
              context "when single version" do
                setup do
                  set(:post, create_post.call(:public => false))
                end

                behaves_as(:get_post)

                behaves_as(:delete_post_with_record)

                behaves_as(:not_found_get_post)
              end

              context "when multiple versions" do
                setup do
                  post = create_post.call(:public => false)
                  create_post_version.call(post, :public => true, :version => {
                    :parents => [{ :version => post[:version][:id], :post => post[:id] }]
                  })
                  set(:post, post)
                end

                behaves_as(:get_post)

                behaves_as(:delete_post_with_record)

                behaves_as(:not_found_get_post)
              end
            end

            context "with Create-Delete-Post header set to false" do
              context "when single version" do
                setup do
                  set(:post, create_post.call(:public => false))
                end

                behaves_as(:get_post)

                behaves_as(:delete_post_without_record)

                behaves_as(:not_found_get_post)
              end

              context "when multiple versions" do
                setup do
                  post = create_post.call(:public => false)
                  create_post_version.call(post, :public => true, :version => {
                    :parents => [{ :version => post[:version][:id], :post => post[:id] }]
                  })
                  set(:post, post)
                end

                behaves_as(:get_post)

                behaves_as(:delete_post_without_record)

                behaves_as(:not_found_get_post)
              end
            end
          end

          context "when full authorization" do
            setup do
              set(:client, clients(:app_auth))
            end

            context "without Create-Delete-Post header set" do
              context "when single version" do
                setup do
                  set(:post, create_post.call(:public => false))
                end

                behaves_as(:get_post)

                behaves_as(:delete_post_with_record)

                behaves_as(:not_found_get_post)
              end

              context "when multiple versions" do
                setup do
                  post = create_post.call(:public => false)
                  create_post_version.call(post, :public => true, :version => {
                    :parents => [{ :version => post[:version][:id], :post => post[:id] }]
                  })
                  set(:post, post)
                end

                behaves_as(:get_post)

                behaves_as(:delete_post_with_record)

                behaves_as(:not_found_get_post)
              end
            end

            context "with Create-Delete-Post header set to false" do
              context "when single version" do
                setup do
                  set(:post, create_post.call(:public => false))
                end

                behaves_as(:get_post)

                behaves_as(:delete_post_without_record)

                behaves_as(:not_found_get_post)
              end

              context "when multiple versions" do
                setup do
                  post = create_post.call(:public => false)
                  create_post_version.call(post, :public => true, :version => {
                    :parents => [{ :version => post[:version][:id], :post => post[:id] }]
                  })
                  set(:post, post)
                end

                behaves_as(:get_post)

                behaves_as(:delete_post_without_record)

                behaves_as(:not_found_get_post)
              end
            end
          end
        end

        context "without authentication" do
          setup do
            set(:post, create_post.call(:public => false))
            set(:client, clients(:no_auth))
          end

          behaves_as(:not_found_get_post)

          behaves_as(:not_found_delete_post)

          behaves_as(:not_found_get_post)
        end
      end
    end

    describe "DELETE post version" do
      shared_example :setup do
        expect_response(:status => 200, :schema => :data) do
          data = generate_status_post(get(:public))

          expected_data = TentD::Utils::Hash.deep_dup(data)

          if get(:public)
            expected_data.delete(:permissions)
          end

          expect_properties(:post => expected_data)

          clients(:app_auth).post.create(data)
        end.after do |response, results|
          if results.any? { |r| !r[:valid] }
            raise SetupFailure.new("Failed to create post", response, results)
          else
            post = TentD::Utils::Hash.symbolize_keys(response.body['post'])
            set(:post, post)
          end
        end

        expect_response(:status => 200, :schema => :data) do
          post = get(:post)
          data = generate_status_post(get(:public))

          expected_data = TentD::Utils::Hash.deep_dup(data)

          if get(:public)
            expected_data.delete(:permissions)
          end

          expect_properties(:post => expected_data)

          clients(:app_auth).post.update(post[:entity], post[:id], data)
        end.after do |response, results|
          if results.any? { |r| !r[:valid] }
            raise SetupFailure.new("Failed to create post version", response, results)
          else
            post = TentD::Utils::Hash.symbolize_keys(response.body['post'])
            set(:post_version, post)
          end
        end
      end

      shared_example :delete_version do
        expect_response(:status => 200, :schema => :data) do
          post_version = get(:post_version)

          expect_properties(:post => post_version)

          get(:client).post.get(post_version[:entity], post_version[:id])
        end

        expect_response(:status => 200) do
          post_version = get(:post_version)
          create_delete_post = get(:create_delete_post)

          if create_delete_post != false
            expect_schema(:data, '/')
            expect_properties(:post => {
              :entity => post_version[:entity],
              :type => "https://tent.io/types/delete/v0#",
              :refs => [{ :post => post_version[:id], :version => post_version[:version][:id] }]
            })
          else
            expect_body('')
          end

          get(:client).post.delete(post_version[:entity], post_version[:id], :version => post_version[:version][:id]) do |req|
            case create_delete_post
            when false
              req.headers['Create-Delete-Post'] = 'false'
            when true
              req.headers['Create-Delete-Post'] = 'true'
            end
          end
        end

        expect_response(:status => 200, :schema => :data) do
          post = get(:post)

          expect_properties(:post => post)

          get(:client).post.get(post[:entity], post[:id])
        end
      end

      shared_example :not_found do
        expect_response(:status => 200, :schema => :data) do
          post_version = get(:post_version)

          expect_properties(:post => post_version)

          clients(:app_auth).post.get(post_version[:entity], post_version[:id])
        end

        expect_response(:status => 404, :schema => :error) do
          post_version = get(:post_version)
          create_delete_post = get(:create_delete_post)

          get(:client).post.delete(post_version[:entity], post_version[:id], :version => post_version[:version][:id]) do |req|
            case create_delete_post
            when false
              req.headers['Create-Delete-Post'] = 'false'
            when true
              req.headers['Create-Delete-Post'] = 'true'
            end
          end
        end

        expect_response(:status => 200, :schema => :data) do
          post_version = get(:post_version)

          expect_properties(:post => post_version)

          clients(:app_auth).post.get(post_version[:entity], post_version[:id])
        end
      end

      shared_example :not_authorized do
        expect_response(:status => 200, :schema => :data) do
          post_version = get(:post_version)

          expect_properties(:post => post_version)

          clients(:app_auth).post.get(post_version[:entity], post_version[:id])
        end

        expect_response(:status => 403, :schema => :error) do
          post_version = get(:post_version)
          create_delete_post = get(:create_delete_post)

          get(:client).post.delete(post_version[:entity], post_version[:id], :version => post_version[:version][:id]) do |req|
            case create_delete_post
            when false
              req.headers['Create-Delete-Post'] = 'false'
            when true
              req.headers['Create-Delete-Post'] = 'true'
            end
          end
        end

        expect_response(:status => 200, :schema => :data) do
          post_version = get(:post_version)

          expect_properties(:post => post_version)

          clients(:app_auth).post.get(post_version[:entity], post_version[:id])
        end
      end

      shared_example :not_authorized_401 do
        expect_response(:status => 200, :schema => :data) do
          post_version = get(:post_version)

          expect_properties(:post => post_version)

          clients(:app_auth).post.get(post_version[:entity], post_version[:id])
        end

        expect_response(:status => 401, :schema => :error) do
          post_version = get(:post_version)
          create_delete_post = get(:create_delete_post)

          get(:client).post.delete(post_version[:entity], post_version[:id], :version => post_version[:version][:id]) do |req|
            case create_delete_post
            when false
              req.headers['Create-Delete-Post'] = 'false'
            when true
              req.headers['Create-Delete-Post'] = 'true'
            end
          end
        end

        expect_response(:status => 200, :schema => :data) do
          post_version = get(:post_version)

          expect_properties(:post => post_version)

          clients(:app_auth).post.get(post_version[:entity], post_version[:id])
        end
      end

      context "when public post" do
        setup do
          set(:public, true)
        end

        context "when `Create-Delete-Post` header not set" do
          context "with authentication" do
            context "when type not authorized" do
              authenticate_with_permissions(:write_types => ["https://tent.io/types/status/v0#reply"])

              behaves_as(:setup)
              behaves_as(:not_authorized)
            end

            context "when limited authorization" do
              authenticate_with_permissions(:write_types => ["https://tent.io/types/status/v0#"])

              behaves_as(:setup)
              behaves_as(:delete_version)
            end

            context "when full authorization" do
              setup do
                set(:client, clients(:app_auth))
              end

              behaves_as(:setup)
              behaves_as(:delete_version)
            end
          end

          context "without authentication" do
            setup do
              set(:client, clients(:no_auth))
            end

            behaves_as(:setup)
            behaves_as(:not_authorized_401)
          end
        end

        context "when `Create-Delete-Post` header set to `true`" do
          setup do
            set(:create_delete_post, true)
          end

          context "with authentication" do
            context "when type not authorized" do
              authenticate_with_permissions(:write_types => ["https://tent.io/types/status/v0#reply"])

              behaves_as(:setup)
              behaves_as(:not_authorized)
            end

            context "when limited authorization" do
              authenticate_with_permissions(:write_types => ["https://tent.io/types/status/v0#"])

              behaves_as(:setup)
              behaves_as(:delete_version)
            end

            context "when full authorization" do
              setup do
                set(:client, clients(:app_auth))
              end

              behaves_as(:setup)
              behaves_as(:delete_version)
            end
          end

          context "without authentication" do
            setup do
              set(:client, clients(:no_auth))
            end

            behaves_as(:setup)
            behaves_as(:not_authorized_401)
          end
        end

        context "when `Create-Delete-Post` header set to `false`" do
          setup do
            set(:create_delete_post, false)
          end

          context "with authentication" do
            context "when type not authorized" do
              authenticate_with_permissions(:write_types => ["https://tent.io/types/status/v0#reply"])

              behaves_as(:setup)
              behaves_as(:not_authorized)
            end

            context "when limited authorization" do
              authenticate_with_permissions(:write_types => ["https://tent.io/types/status/v0#"])

              behaves_as(:setup)
              behaves_as(:delete_version)
            end

            context "when full authorization" do
              setup do
                set(:client, clients(:app_auth))
              end

              behaves_as(:setup)
              behaves_as(:delete_version)
            end
          end

          context "without authentication" do
            setup do
              set(:client, clients(:no_auth))
            end

            behaves_as(:setup)
            behaves_as(:not_authorized_401)
          end
        end
      end

      context "when private post" do
        setup do
          set(:public, false)
        end

        context "when `Create-Delete-Post` header not set" do
          context "with authentication" do
            context "when type not authorized" do
              authenticate_with_permissions(:write_types => ["https://tent.io/types/status/v0#reply"])

              behaves_as(:setup)
              behaves_as(:not_found)
            end

            context "when limited authorization" do
              authenticate_with_permissions(:write_types => ["https://tent.io/types/status/v0#"])

              behaves_as(:setup)
              behaves_as(:delete_version)
            end

            context "when full authorization" do
              setup do
                set(:client, clients(:app_auth))
              end

              behaves_as(:setup)
              behaves_as(:delete_version)
            end
          end

          context "without authentication" do
            setup do
              set(:client, clients(:no_auth))
            end

            behaves_as(:setup)
            behaves_as(:not_found)
          end
        end

        context "when `Create-Delete-Post` header set to `true`" do
          setup do
            set(:create_delete_post, true)
          end

          context "with authentication" do
            context "when type not authorized" do
              authenticate_with_permissions(:write_types => ["https://tent.io/types/status/v0#reply"])

              behaves_as(:setup)
              behaves_as(:not_found)
            end

            context "when limited authorization" do
              authenticate_with_permissions(:write_types => ["https://tent.io/types/status/v0#"])

              behaves_as(:setup)
              behaves_as(:delete_version)
            end

            context "when full authorization" do
              setup do
                set(:client, clients(:app_auth))
              end

              behaves_as(:setup)
              behaves_as(:delete_version)
            end
          end

          context "without authentication" do
            setup do
              set(:client, clients(:no_auth))
            end

            behaves_as(:setup)
            behaves_as(:not_found)
          end
        end

        context "when `Create-Delete-Post` header set to `false`" do
          setup do
            set(:create_delete_post, false)
          end

          context "with authentication" do
            context "when type not authorized" do
              authenticate_with_permissions(:write_types => ["https://tent.io/types/status/v0#reply"])

              behaves_as(:setup)
              behaves_as(:not_found)
            end

            context "when limited authorization" do
              authenticate_with_permissions(:write_types => ["https://tent.io/types/status/v0#"])

              behaves_as(:setup)
              behaves_as(:delete_version)
            end

            context "when full authorization" do
              setup do
                set(:client, clients(:app_auth))
              end

              behaves_as(:setup)
              behaves_as(:delete_version)
            end
          end

          context "without authentication" do
            setup do
              set(:client, clients(:no_auth))
            end

            behaves_as(:setup)
            behaves_as(:not_found)
          end
        end
      end
    end

    describe "DELETE post when entity is foreign" do
      # import post of foreign decent
      # expect post to be accessible
      # DELETE post
      # expect no delete post to be created
      # expect post to not be accessible

      shared_example :setup do
        expect_response(:status => 200, :schema => :data) do
          foreign_entity = "https://fictitious-#{TentD::Utils.timestamp}.example.com"
          set(:foreign_entity, foreign_entity)

          data = generate_status_post(get(:public)).merge(
            :id => TentD::Utils.random_id,
            :entity => foreign_entity,
            :published_at => TentD::Utils.timestamp,
            :received_at => TentD::Utils.timestamp,
            :version => {
              :published_at => TentD::Utils.timestamp,
              :received_at => TentD::Utils.timestamp
            }
          )
          data[:version][:id] = generate_version_signature(data)

          set(:post, data)

          expected_data = TentD::Utils::Hash.deep_dup(data)
          expected_data.delete(:permissions) if get(:public)
          expect_properties(:post => expected_data)

          clients(:app_auth).post.update(data[:entity], data[:id], data, {}, :import => true)
        end.after do |response, results, validator|
          if results.any? { |r| !r[:valid] }
            raise SetupFailure.new("Failed to import post", response, results, validator)
          end
        end
      end

      shared_example :delete_post do
        # make sure we can get the post
        expect_response(:status => 200, :schema => :data) do
          post = get(:post)

          expected_data = TentD::Utils::Hash.deep_dup(post)
          expected_data.delete(:permissions) if get(:public)
          expect_properties(:post => expected_data)

          get(:client).post.get(post[:entity], post[:id])
        end

        # delete the post
        expect_response(:status => 200) do
          post = get(:post)

          expect_body('')

          get(:client).post.delete(post[:entity], post[:id])
        end

        # make sure we can no longer get the post
        expect_response(:status => 404, :schema => :error) do
          post = get(:post)
          get(:client).post.get(post[:entity], post[:id])
        end
      end

      shared_example :unauthorized_delete_post do
        # make sure we can get the post
        expect_response(:status => 200, :schema => :data) do
          post = get(:post)

          expected_data = TentD::Utils::Hash.deep_dup(post)
          expected_data.delete(:permissions) if get(:public)
          expect_properties(:post => expected_data)

          clients(:app_auth).post.get(post[:entity], post[:id])
        end

        # delete the post
        expect_response(:status => 403) do
          post = get(:post)
          get(:client).post.delete(post[:entity], post[:id])
        end

        # make sure we can still get the post
        expect_response(:status => 200, :schema => :data) do
          post = get(:post)

          expected_data = TentD::Utils::Hash.deep_dup(post)
          expected_data.delete(:permissions) if get(:public)
          expect_properties(:post => expected_data)

          clients(:app_auth).post.get(post[:entity], post[:id])
        end
      end

      shared_example :unauthorized_delete_post_401 do
        # make sure we can get the post
        expect_response(:status => 200, :schema => :data) do
          post = get(:post)

          expected_data = TentD::Utils::Hash.deep_dup(post)
          expected_data.delete(:permissions) if get(:public)
          expect_properties(:post => expected_data)

          clients(:app_auth).post.get(post[:entity], post[:id])
        end

        # delete the post
        expect_response(:status => 401) do
          post = get(:post)
          get(:client).post.delete(post[:entity], post[:id])
        end

        # make sure we can still get the post
        expect_response(:status => 200, :schema => :data) do
          post = get(:post)

          expected_data = TentD::Utils::Hash.deep_dup(post)
          expected_data.delete(:permissions) if get(:public)
          expect_properties(:post => expected_data)

          clients(:app_auth).post.get(post[:entity], post[:id])
        end
      end

      shared_example :not_found do
        # make sure we can get the post
        expect_response(:status => 200, :schema => :data) do
          post = get(:post)

          expected_data = TentD::Utils::Hash.deep_dup(post)
          expected_data.delete(:permissions) if get(:public)
          expect_properties(:post => expected_data)

          clients(:app_auth).post.get(post[:entity], post[:id])
        end

        # delete the post
        expect_response(:status => 404) do
          post = get(:post)
          get(:client).post.delete(post[:entity], post[:id])
        end

        # make sure we can still get the post
        expect_response(:status => 200, :schema => :data) do
          post = get(:post)

          expected_data = TentD::Utils::Hash.deep_dup(post)
          expected_data.delete(:permissions) if get(:public)
          expect_properties(:post => expected_data)

          clients(:app_auth).post.get(post[:entity], post[:id])
        end
      end

      context "when post is public" do
        setup do
          set(:public, true)
        end

        context "when authenticated" do
          context "when not authorized" do
            authenticate_with_permissions(:write_types => %w( https://tent.io/types/status/v0#reply ))

            behaves_as(:setup)
            behaves_as(:unauthorized_delete_post)
          end

          context "when limited authorization" do
            authenticate_with_permissions(:write_types => %w( https://tent.io/types/status/v0# ))

            behaves_as(:setup)
            behaves_as(:delete_post)
          end

          context "when full authorization" do
            setup do
              set(:client, clients(:app_auth))
            end

            behaves_as(:setup)
            behaves_as(:delete_post)
          end
        end

        context "when not authenticated" do
          setup do
            set(:client, clients(:no_auth))
          end

          behaves_as(:setup)
          behaves_as(:unauthorized_delete_post_401)
        end
      end

      context "when post is private" do
        setup do
          set(:public, false)
        end

        context "when authenticated" do
          context "when not authorized" do
            authenticate_with_permissions(:write_types => %w( https://tent.io/types/status/v0#reply ))

            behaves_as(:setup)
            behaves_as(:not_found)
          end

          context "when limited authorization" do
            authenticate_with_permissions(:write_types => %w( https://tent.io/types/status/v0# ))

            behaves_as(:setup)
            behaves_as(:delete_post)
          end

          context "when full authorization" do
            setup do
              set(:client, clients(:app_auth))
            end

            behaves_as(:setup)
            behaves_as(:delete_post)
          end
        end

        context "when not authenticated" do
          setup do
            set(:client, clients(:no_auth))
          end

          behaves_as(:setup)
          behaves_as(:not_found)
        end
      end
    end

    describe "PUT post with delete post notification" do
      shared_example :setup_relationship do
        include_import_relationship_examples
      end

      shared_example :setup do
        # [author:fake] status# post notification using [author:remote] relationship credentials
        expect_response(:status => 200, :schema => :data) do
          data = generate_status_post.merge(
            :entity => get(:fake_entity),
            :id => TentD::Utils.random_id,
            :published_at => TentD::Utils.timestamp,
            :received_at => TentD::Utils.timestamp,
            :version => {
              :published_at => TentD::Utils.timestamp,
              :received_at => TentD::Utils.timestamp
            }
          )
          data[:version][:id] = generate_version_signature(data)

          set(:fake_status, data)

          remote_credentials = get(:remote_credentials)
          client = clients(:custom, remote_credentials[:content].merge(:id => remote_credentials[:id]))

          client.post.update(data[:entity], data[:id], data, {}, :notification => true)
        end.after do |response, results, validator|
          if results.any? { |r| !r[:valid] }
            raise SetupFailure.new("Failed to import post", response, results, validator)
          end
        end
      end

      shared_example :delete_notification do
        # make sure we can get the status post
        expect_response(:status => 200, :schema => :data) do
          post = get(:fake_status)

          expected_data = TentD::Utils::Hash.deep_dup(post)
          expected_data.delete(:received_at)
          expected_data.delete(:permissions)
          expected_data[:version].delete(:received_at)
          expect_properties(:post => expected_data)

          clients(:app_auth).post.get(post[:entity], post[:id])
        end

        # send delete notification for the status post
        expect_response(:status => 200) do
          post = get(:fake_status)

          data = generate_status_post.merge(
            :entity => get(:fake_entity),
            :id => TentD::Utils.random_id,
            :type => %(https://tent.io/types/delete/v0#),
            :published_at => TentD::Utils.timestamp,
            :received_at => TentD::Utils.timestamp,
            :refs => [{ :entity => post[:entity], :post => post[:id] }],
            :version => {
              :published_at => TentD::Utils.timestamp,
              :received_at => TentD::Utils.timestamp
            }
          )
          data[:version][:id] = generate_version_signature(data)

          get(:client).post.update(data[:entity], data[:id], data, {}, :notification => true)
        end

        # make sure we can't get the status post
        expect_response(:status => 404, :schema => :error) do
          post = get(:fake_status)
          clients(:app_auth).post.get(post[:entity], post[:id])
        end
      end

      shared_example :not_authorized do
        # make sure we can get the status post
        expect_response(:status => 200, :schema => :data) do
          post = get(:fake_status)

          expected_data = TentD::Utils::Hash.deep_dup(post)
          expected_data.delete(:received_at)
          expected_data.delete(:permissions)
          expected_data[:version].delete(:received_at)
          expect_properties(:post => expected_data)

          clients(:app_auth).post.get(post[:entity], post[:id])
        end

        # send delete notification for the status post
        expect_response(:status => 403) do
          post = get(:fake_status)

          data = generate_status_post.merge(
            :entity => get(:fake_entity),
            :id => TentD::Utils.random_id,
            :type => %(https://tent.io/types/delete/v0#),
            :published_at => TentD::Utils.timestamp,
            :received_at => TentD::Utils.timestamp,
            :refs => [{ :entity => post[:entity], :post => post[:id] }],
            :version => {
              :published_at => TentD::Utils.timestamp,
              :received_at => TentD::Utils.timestamp
            }
          )
          data[:version][:id] = generate_version_signature(data)

          get(:client).post.update(data[:entity], data[:id], data, {}, :notification => true)
        end

        # make sure we can still get the status post
        expect_response(:status => 200, :schema => :data) do
          post = get(:fake_status)

          expected_data = TentD::Utils::Hash.deep_dup(post)
          expected_data.delete(:received_at)
          expected_data.delete(:permissions)
          expected_data[:version].delete(:received_at)
          expect_properties(:post => expected_data)

          clients(:app_auth).post.get(post[:entity], post[:id])
        end
      end

      behaves_as :setup_relationship

      context "when signed using valid relationship credentials" do
        setup do
          remote_credentials = get(:remote_credentials)
          client = clients(:custom, remote_credentials[:content].merge(:id => remote_credentials[:id]))

          set(:client, client)
        end

        behaves_as :setup
        behaves_as :delete_notification
      end

      context "when signed using invalid relationship credentials" do
        setup do
          client = clients(:custom,
           :id => 'fake-id',
           :hawk_key => 'fake-key',
           :hawk_algorithm => TentD::Utils.hawk_algorithm
          )

          set(:client, client)
        end

        behaves_as :setup
        behaves_as :not_authorized
      end

      context "when not signed" do
        setup do
          set(:client, clients(:no_auth))
        end

        behaves_as :setup
        behaves_as :not_authorized
      end
    end

    describe "GET post with mentions accept header" do
      shared_example :get_all_mentions do
        expect_response(:status => 200, :schema => :data) do
          expect_properties(:mentions => get(:posts).reverse.map { |post|
            m = { :post => post[:id], :type => post[:type] }
            m[:entity] = post[:entity] unless post[:entity] == get(:post)[:entity]
            m[:public] = false if TentD::TentType.new(post[:type]).fragment == 'reply' # see setup block
            m
          })

          expect_headers('Content-Type' => %(application/vnd.tent.post-mentions.v0+json))

          post = get(:post)
          get(:client).post.mentions(post[:entity], post[:id])
        end

        expect_response(:status => 200) do
          expect_headers('Count' => /\A\d+\Z/)
          expect_headers('Content-Type' => %(application/vnd.tent.post-mentions.v0+json))

          post = get(:post)
          get(:client).post.head.mentions(post[:entity], post[:id])
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

        expect_response(:status => 200) do
          expect_headers('Count' => /\A\d+\Z/)
          expect_headers('Content-Type' => %(application/vnd.tent.post-mentions.v0+json))

          post = get(:post)
          get(:client).post.head.mentions(post[:entity], post[:id])
        end
      end

      context "when public" do
        setup do
          post = create_post.call(:public => true)

          opts = {
            :mentions => [{ :entity => post[:entity], :type => post[:type], :post => post[:id] }]
          }

          private_opts = TentD::Utils::Hash.deep_dup(opts)
          private_opts[:mentions].first[:public] = false

          post_1 = create_post.call(opts.merge(:public => true))
          post_2 = create_post.call(private_opts.merge(:public => true, :type => %(https://tent.io/types/status/v0#reply)))
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
            authenticate_with_permissions(:read_types => %w(https://tent.io/types/status/v0#))

            behaves_as(:get_all_mentions)
          end

          context "when full authorization" do
            setup do
              set(:client, clients(:app_auth))
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

          private_opts = TentD::Utils::Hash.deep_dup(opts)
          private_opts[:mentions].first[:public] = false

          post_1 = create_post.call(opts.merge(:public => true))
          post_2 = create_post.call(private_opts.merge(:public => true, :type => %(https://tent.io/types/status/v0#reply)))
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
            authenticate_with_permissions(:read_types => %w(https://tent.io/types/status/v0#))

            behaves_as(:get_all_mentions)
          end

          context "when full authorization" do
            setup do
              set(:client, clients(:app_auth))
            end

            behaves_as(:get_all_mentions)
          end
        end
      end
    end

    describe "GET post with children accept header" do
      set(:post_type, %(https://tent.io/types/status/v0#))

      create_public_versions = lambda do |post, opts={}|
        post_type = post[:type]

        if opts[:parent]
          method = :post
        else
          method = :put
        end

        opts[:parent] ||= post

        versions = 3.times.map do
          if method == :put
            create_post_version.call(post, :type => post_type, :public => true, :version => {
              :parents => [{ :version => opts[:parent][:version][:id], :post => opts[:parent][:id] }]
            })
          else
            create_post.call(:type => post_type, :public => true, :version => {
              :parents => [{ :version => opts[:parent][:version][:id], :post => opts[:parent][:id] }]
            })
          end
        end

        versions
      end

      create_public_and_private_versions = lambda do |post, opts={}|
        post_type = post[:type]

        if opts[:parent]
          method = :post
        else
          method = :put
        end

        opts[:parent] ||= post

        public_versions = 2.times.map do
          if method == :put
            create_post_version.call(post, :type => post_type, :public => true, :version => {
              :parents => [{ :version => opts[:parent][:version][:id], :post => opts[:parent][:id] }]
            })
          else
            create_post.call(:type => post_type, :public => true, :version => {
              :parents => [{ :version => opts[:parent][:version][:id], :post => opts[:parent][:id] }]
            })
          end
        end

        private_versions = 2.times.map do
          if method == :put
            create_post_version.call(post, :type => post_type, :public => false, :version => {
              :parents => [{ :version => opts[:parent][:version][:id], :post => opts[:parent][:id] }]
            })
          else
            create_post.call(:type => post_type, :public => false, :version => {
              :parents => [{ :version => opts[:parent][:version][:id], :post => opts[:parent][:id] }]
            })
          end
        end

        public_versions_2 = 2.times.map do
          if method == :put
            create_post_version.call(post, :type => post_type, :public => true, :version => {
              :parents => [{ :version => opts[:parent][:version][:id], :post => opts[:parent][:id] }]
            })
          else
            create_post.call(:type => post_type, :public => true, :version => {
              :parents => [{ :version => opts[:parent][:version][:id], :post => opts[:parent][:id] }]
            })
          end
        end

        public_versions + private_versions + public_versions_2
      end

      create_private_versions = lambda do |post, opts={}|
        post_type = post[:type]

        if opts[:parent]
          method = :post
        else
          method = :put
        end

        opts[:parent] ||= post

        versions = 3.times.map do
          if method == :put
            create_post_version.call(post, :type => post_type, :public => false, :version => {
              :parents => [{ :version => opts[:parent][:version][:id], :post => opts[:parent][:id] }]
            })
          else
            create_post.call(:type => post_type, :public => false, :version => {
              :parents => [{ :version => opts[:parent][:version][:id], :post => opts[:parent][:id] }]
            })
          end
        end

        versions
      end

      shared_example :all_versions do
        expect_response(:status => 200, :schema => :data) do
          expect_headers('Content-Type' => %(application/vnd.tent.post-children.v0+json))

          params = {}

          if version_id = get(:version_id)
            params[:version] = version_id
          end

          post = get(:post)
          versions_parent = get(:parent)
          versions = get(:versions)

          versions = get(:versions).map do |post|
            unless get(:is_app)
              post = TentD::Utils::Hash.deep_dup(post)
              post[:version].delete(:received_at)
            end

            post[:version].merge(:type => post[:type])
          end.each do |version|
            version[:parents].each do |parent|
              if !versions_parent || parent[:post] == versions_parent[:id]
                parent[:post] = property_absent
              else
                parent[:post] = post[:id]
              end
            end
          end

          expect_properties(:versions => versions.reverse)
          expect_property_length('/versions', versions.size)

          get(:client).post.children(post[:entity], post[:id], params)
        end

        expect_response(:status => 200) do
          expect_headers('Count' => /\A\d+\Z/)
          expect_headers('Content-Type' => %(application/vnd.tent.post-children.v0+json))

          params = {}

          if version_id = get(:version_id)
            params[:version] = version_id
          end

          post = get(:post)

          get(:client).post.head.children(post[:entity], post[:id], params)
        end
      end

      shared_example :public_versions do
        expect_response(:status => 200, :schema => :data) do
          expect_headers('Content-Type' => %(application/vnd.tent.post-children.v0+json))

          params = {}

          if version_id = get(:version_id)
            params[:version] = version_id
          end

          post = get(:post)
          versions_parent = get(:parent)
          versions = get(:versions).select { |post| !post[:permissions] }.map do |post|
            unless get(:is_app)
              post = TentD::Utils::Hash.deep_dup(post)
              post[:version].delete(:received_at)
            end

            post[:version].merge(:type => post[:type])
          end.each do |version|
            version[:parents].each do |parent|
              if !versions_parent || parent[:post] == versions_parent[:id]
                parent[:post] = property_absent
              else
                parent[:post] = post[:id]
              end
            end
          end

          expect_properties(:versions => versions.reverse)
          expect_property_length('/versions', versions.size)

          get(:client).post.children(post[:entity], post[:id], params)
        end

        expect_response(:status => 200) do
          expect_headers('Count' => /\A\d+\Z/)
          expect_headers('Content-Type' => %(application/vnd.tent.post-children.v0+json))

          params = {}

          if version_id = get(:version_id)
            params[:version] = version_id
          end

          post = get(:post)

          get(:client).post.head.children(post[:entity], post[:id], params)
        end
      end

      shared_example :not_found do
        expect_response(:status => 404, :schema => :error) do
          params = {}

          if version_id = get(:version_id)
            params[:version] = version_id
          end

          post = get(:post)

          get(:client).post.children(post[:entity], post[:id], params)
        end
      end

      shared_example :not_authorized do
        context "with public versions" do
          context "when no version specified" do
            setup do
              post = create_post.call(:public => true, :type => get(:post_type))
              parent = create_post.call(:public => true, :type => get(:post_type))
              children = create_public_versions.call(parent, :parent => post)
              set(:post, post)
              set(:versions, children)
              set(:parent, parent)
            end

            behaves_as(:all_versions)
          end

          context "when version specified" do
            setup do
              post = create_post.call(:public => true, :type => get(:post_type))
              version = create_public_versions.call(post)[1]
              children = create_public_versions.call(version)
              set(:post, version)
              set(:versions, children)

              set(:version_id, version[:version][:id])
            end

            behaves_as(:all_versions)
          end
        end

        context "with public and private versions" do
          context "when no version specified" do
            setup do
              post = create_post.call(:public => true, :type => get(:post_type))
              parent = create_post.call(:public => true, :type => get(:post_type))
              children = create_public_and_private_versions.call(parent, :parent => post)
              set(:post, post)
              set(:versions, children)
              set(:parent, parent)
            end

            behaves_as(:public_versions)
          end

          context "when private version specified" do
            setup do
              post = create_post.call(:public => true, :type => get(:post_type))
              version = create_public_and_private_versions.call(post).find { |post| post[:permissions] }
              children = create_public_and_private_versions.call(version)
              set(:post, version)
              set(:versions, children)

              set(:version_id, version[:version][:id])
            end

            behaves_as(:not_found)
          end

          context "when public version specified" do
            setup do
              post = create_post.call(:public => true, :type => get(:post_type))
              version = create_public_and_private_versions.call(post).find { |post| !post[:permissions] }
              children = create_public_and_private_versions.call(version)
              set(:post, version)
              set(:versions, children)

              set(:version_id, version[:version][:id])
            end

            behaves_as(:public_versions)
          end
        end

        context "with private versions" do
          context "when no version specified" do
            setup do
              post = create_post.call(:public => true, :type => get(:post_type))
              parent = create_post.call(:public => true, :type => get(:post_type))
              children = create_private_versions.call(parent, :parent => post)
              set(:post, post)
              set(:versions, [])
              set(:parent, parent)
            end

            behaves_as(:all_versions)
          end

          context "when version specified" do
            setup do
              post = create_post.call(:public => true, :type => get(:post_type))
              version = create_private_versions.call(post)[1]
              children = create_private_versions.call(version)
              set(:post, version)
              set(:versions, children)

              set(:version_id, version[:version][:id])
            end

            behaves_as(:not_found)
          end
        end
      end

      shared_example :authorized do
        context "with public versions" do
          context "when no version specified" do
            setup do
              post = create_post.call(:public => true, :type => get(:post_type))
              parent = create_post.call(:public => true, :type => get(:post_type))
              children = create_public_versions.call(parent, :parent => post)
              set(:post, post)
              set(:versions, children)
              set(:parent, parent)
            end

            behaves_as(:all_versions)
          end

          context "when version specified" do
            setup do
              post = create_post.call(:public => true, :type => get(:post_type))
              version = create_public_versions.call(post)[1]
              children = create_public_versions.call(version)
              set(:post, version)
              set(:versions, children)

              set(:version_id, version[:version][:id])
            end

            behaves_as(:all_versions)
          end
        end

        context "with public and private versions" do
          context "when no version specified" do
            setup do
              post = create_post.call(:public => true, :type => get(:post_type))
              parent = create_post.call(:public => true, :type => get(:post_type))
              children = create_public_and_private_versions.call(parent, :parent => post)
              set(:post, post)
              set(:versions, children)
              set(:parent, parent)
            end

            behaves_as(:all_versions)
          end

          context "when private version specified" do
            setup do
              post = create_post.call(:public => true, :type => get(:post_type))
              version = create_public_and_private_versions.call(post).find { |post| post[:permissions] }
              children = create_public_and_private_versions.call(version)
              set(:post, version)
              set(:versions, children)

              set(:version_id, version[:version][:id])
            end

            behaves_as(:all_versions)
          end

          context "when public version specified" do
            setup do
              post = create_post.call(:public => true, :type => get(:post_type))
              version = create_public_and_private_versions.call(post).find { |post| !post[:permissions] }
              children = create_public_and_private_versions.call(version)
              set(:post, version)
              set(:versions, children)

              set(:version_id, version[:version][:id])
            end

            behaves_as(:all_versions)
          end
        end

        context "with private versions" do
          context "when no version specified" do
            setup do
              post = create_post.call(:public => true, :type => get(:post_type))
              parent = create_post.call(:public => true, :type => get(:post_type))
              children = create_private_versions.call(parent, :parent => post)
              set(:post, post)
              set(:versions, children)
              set(:parent, parent)
            end

            behaves_as(:all_versions)
          end

          context "when version specified" do
            setup do
              post = create_post.call(:public => true, :type => get(:post_type))
              version = create_private_versions.call(post).last
              children = create_private_versions.call(version)
              set(:post, version)
              set(:versions, children)

              set(:version_id, version[:version][:id])
            end

            behaves_as(:all_versions)
          end
        end
      end

      context "without auth" do
        setup do
          set(:is_app, false)
        end

        setup do
          set(:client, clients(:no_auth))
        end

        behaves_as(:not_authorized)
      end

      context "with auth" do
        setup do
          set(:is_app, true)
        end

        context "when not authorized" do
          authenticate_with_permissions(:read_types => [])

          behaves_as(:not_authorized)
        end

        context "when limited authorization" do
          authenticate_with_permissions(:read_types => [get(:post_type)])

          behaves_as(:authorized)
        end

        context "when full authorization" do
          setup do
            set(:client, clients(:app_auth))
          end

          behaves_as(:authorized)
        end
      end
    end

    describe "GET post versions" do
      set(:post_type, %(https://tent.io/types/status/v0#reply))

      create_versions = lambda do |post, opts|
        version_parent = { :version => post[:version][:id], :post => post[:id] }
        versions = 3.times.map do
          create_post_version.call(post, :type => get(:post_type), :public => opts[:public], :version => { :parents => [version_parent] })
        end

        versions
      end

      shared_example :all_versions do
        expect_response(:status => 200, :schema => :data) do
          post = get(:post)
          versions = get(:versions)
          is_app = get(:is_app)

          expect_headers('Content-Type' => %(application/vnd.tent.post-versions.v0+json))

          expect_property_length('/versions', versions.size)
          expect_properties(:versions => versions.reverse.map { |_post|
            version = TentD::Utils::Hash.deep_dup(_post[:version])
            (version[:parents] || []).each { |parent| parent.delete(:post) }
            version[:type] = _post[:type]
            version[:received_at] = property_absent unless is_app
            version
          })

          get(:client).post.versions(post[:entity], post[:id])
        end

        expect_response(:status => 200) do
          post = get(:post)
          versions = get(:versions)

          expect_headers('Content-Type' => %(application/vnd.tent.post-versions.v0+json))
          expect_headers('Count' => versions.size.to_s)

          get(:client).post.head.versions(post[:entity], post[:id])
        end
      end

      shared_example :not_found do
        expect_response(:status => 404, :schema => :error) do
          post = get(:post)
          get(:client).post.versions(post[:entity], post[:id])
        end
      end

      context "when post and versions public" do
        setup do
          post = create_post.call(:public => true, :type => get(:post_type))
          versions = create_versions.call(post, :public => true)

          set(:post, post)
          set(:versions, [post] + versions)
        end

        context "when not authenticated" do
          setup do
            set(:is_app, false)
            set(:client, clients(:no_auth))
          end

          behaves_as(:all_versions)
        end

        context "when authenticated" do
          setup do
            set(:is_app, true)
          end

          context "without authorization" do
            authenticate_with_permissions(:read_types => [])

            behaves_as(:all_versions)
          end

          context "with limited authorization" do
            authenticate_with_permissions(:read_types => [get(:post_type)])

            behaves_as(:all_versions)
          end

          context "with full authorization" do
            setup do
              set(:client, clients(:app_auth))
            end

            behaves_as(:all_versions)
          end
        end
      end

      context "when post private and versions public" do
        setup do
          post = create_post.call(:public => false, :type => get(:post_type))
          versions = create_versions.call(post, :public => true)

          set(:post, post)
          set(:public_versions, versions)
          set(:versions, [post] + versions)
        end

        context "when not authenticated" do
          setup do
            set(:is_app, false)
            set(:client, clients(:no_auth))
            set(:versions, get(:public_versions))
          end

          behaves_as(:all_versions)
        end

        context "when authenticated" do
          setup do
            set(:is_app, true)
          end

          context "without authorization" do
            authenticate_with_permissions(:read_types => [])

            setup do
              set(:versions, get(:public_versions))
            end

            behaves_as(:all_versions)
          end

          context "with limited authorization" do
            authenticate_with_permissions(:read_types => [get(:post_type)])

            behaves_as(:all_versions)
          end

          context "with full authorization" do
            setup do
              set(:client, clients(:app_auth))
            end

            behaves_as(:all_versions)
          end
        end
      end

      context "when post and versions private" do
        setup do
          post = create_post.call(:public => false, :type => get(:post_type))
          versions = create_versions.call(post, :public => false)

          set(:post, post)
          set(:versions, [post] + versions)
        end

        context "when not authenticated" do
          setup do
            set(:is_app, false)
            set(:client, clients(:no_auth))
          end

          behaves_as(:not_found)
        end

        context "when authenticated" do
          setup do
            set(:is_app, true)
          end

          context "without authorization" do
            authenticate_with_permissions(:read_types => [])

            behaves_as(:not_found)
          end

          context "with limited authorization" do
            authenticate_with_permissions(:read_types => [get(:post_type)])

            behaves_as(:all_versions)
          end

          context "with full authorization" do
            setup do
              set(:client, clients(:app_auth))
            end

            behaves_as(:all_versions)
          end
        end
      end
    end

  end

  TentValidator.validators << PostSingletonValidator
end
