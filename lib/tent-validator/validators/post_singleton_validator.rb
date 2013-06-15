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
        res = clients(:app).post.update(ref_post[:entity], ref_post[:id], data)

        data[:version][:parents].each { |parent| parent.delete(:post) if parent[:post] == ref_post[:id] }

        data[:id] = ref_post[:id]
      else
        res = clients(:app).post.create(data)
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
            m[:public] = false if TentD::TentType.new(post[:type]).fragment == 'reply' # see setup block
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
          authenticate_with_permissions(:read_post_types => [])

          behaves_as(:not_authorized)
        end

        context "when limited authorization" do
          authenticate_with_permissions(:read_post_types => [get(:post_type)])

          behaves_as(:authorized)
        end

        context "when full authorization" do
          setup do
            set(:client, clients(:app))
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
            authenticate_with_permissions(:read_post_types => [])

            behaves_as(:all_versions)
          end

          context "with limited authorization" do
            authenticate_with_permissions(:read_post_types => [get(:post_type)])

            behaves_as(:all_versions)
          end

          context "with full authorization" do
            setup do
              set(:client, clients(:app))
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
            authenticate_with_permissions(:read_post_types => [])

            setup do
              set(:versions, get(:public_versions))
            end

            behaves_as(:all_versions)
          end

          context "with limited authorization" do
            authenticate_with_permissions(:read_post_types => [get(:post_type)])

            behaves_as(:all_versions)
          end

          context "with full authorization" do
            setup do
              set(:client, clients(:app))
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
            authenticate_with_permissions(:read_post_types => [])

            behaves_as(:not_found)
          end

          context "with limited authorization" do
            authenticate_with_permissions(:read_post_types => [get(:post_type)])

            behaves_as(:all_versions)
          end

          context "with full authorization" do
            setup do
              set(:client, clients(:app))
            end

            behaves_as(:all_versions)
          end
        end
      end
    end

  end

  TentValidator.validators << PostSingletonValidator
end
