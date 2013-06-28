module TentValidator
  class PostVersionsValidator < TentValidator::Spec
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

      if attachments = opts[:attachments]
        res = clients(:app_auth).post.create(data, {}, :attachments => attachments.map(&:dup))
      else
        res = clients(:app_auth).post.create(data)
      end

      data.delete(:permissions) if opts[:public] == true
      res_validation = ApiValidator::Json.new(:post => data).validate(res)
      raise SetupFailure.new("Failed to create post!", res, res_validation) unless res_validation[:valid]

      if attachments
        res_validation = ApiValidator::Json.new(
          :post => {
            :attachments => attachments.map { |a|
              a = a.dup
              a.merge!(:digest => hex_digest(a[:data]), :size => a[:data].size)
              a.delete(:data)
              a
            }
          }
        ).validate(res)
        raise SetupFailure.new("Failed to create post with attachments!", res, res_validation) unless res_validation[:valid]
      end

      TentD::Utils::Hash.symbolize_keys(res.body['post'])
    end

    create_post_version = lambda do |post, client, opts={}|
      data = generate_status_post(post[:permissions].nil? || false)
      data[:version] = { :parents => [{:version => post[:version][:id], :post => post[:id]}] }

      if post[:attachments] && opts[:keep_attachments]
        data[:attachments] = post[:attachments]
      end

      if attachments = opts[:attachments]
        res = client.post.update(post[:entity], post[:id], data, {}, :attachments => attachments.map(&:dup))
      else
        res = client.post.update(post[:entity], post[:id], data)
      end

      data[:version][:parents].first.delete(:post)
      set(:post_version, data)

      res
    end

    shared_example :create_post_version do
      context "without auth" do
        expect_response(:status => 401) do
          set(:client, clients(:no_auth))
          get(:create_post_version_response)
        end
      end

      context "with auth" do
        context "when unauthorized" do
          authenticate_with_permissions(:write_types => [])

          expect_response(:status => 403) do
            get(:create_post_version_response)
          end
        end

        context "when limited authorization" do
          setup do
            authenticate_with_permissions(:write_types => [get(:post)[:type]])
          end

          context '' do # workaround to ensure `expect_response`s in `setup` are called first
            expect_response(:status => 200, :schema => :data) do
              res = get(:create_post_version_response)

              if get(:expect_properties_absent)
                expect_properties_absent(*Array(get(:expect_properties_absent)))
              end

              if get(:expect_properties)
                expect_properties(get(:expect_properties))
              end

              expected_data = get(:post_version).merge(:id => get(:post)[:id])
              expected_data[:permissions] = property_absent if expected_data[:permissions] && expected_data[:permissions][:public]
              expect_properties(:post => expected_data)
              expect_schema(:post, '/post')

              res
            end
          end
        end

        context "when full authorization" do
          setup do
            set(:client, clients(:app_auth))
          end

          expect_response(:status => 200, :schema => :data) do
            res = get(:create_post_version_response)

            if get(:expect_properties_absent)
              expect_properties_absent(*Array(get(:expect_properties_absent)))
            end

            if get(:expect_properties)
              expect_properties(get(:expect_properties))
            end

            expected_data = get(:post_version).merge(:id => get(:post)[:id])
            expected_data[:permissions] = property_absent if expected_data[:permissions] && expected_data[:permissions][:public]
            expect_properties(:post => expected_data)
            expect_schema(:post, '/post')

            res
          end
        end
      end
    end

    describe "PUT post" do
      context "when public post" do
        setup do
          post = create_post.call(:public => true)
          set(:post, post)

          set(:create_post_version_response) do
            create_post_version.call(post, get(:client))
          end
        end

        behaves_as(:create_post_version)
      end

      context "when private post" do
        setup do
          post = create_post.call(:public => false)
          set(:post, post)

          set(:create_post_version_response) do
            create_post_version.call(post, get(:client))
          end
        end

        behaves_as(:create_post_version)
      end

      context "when post has attachments" do
        setup do
          attachments = 2.times.map { generate_attachment }
          set(:attachments, attachments)

          post = create_post.call(:public => false, :attachments => attachments)
          set(:post, post)
        end

        context "keep attachments" do
          setup do
            attachments = get(:attachments)

            set(:expect_properties,
              :post => {
                :attachments => attachments.map { |a|
                  a = a.dup
                  a.merge!(:digest => hex_digest(a[:data]), :size => a[:data].size)
                  a.delete(:data)
                  a
                }
              })

            post = get(:post)
            set(:create_post_version_response) do
              create_post_version.call(post.merge(:attachments => attachments.map { |attachment|
                TentD::Utils::Hash.slice(attachment, :name, :category, :content_type).merge(:digest => hex_digest(attachment[:data]))
              }), get(:client), :keep_attachments => true)
            end
          end

          behaves_as(:create_post_version)
        end

        context "keep attachments with new attachments" do
          setup do
            new_attachments = 2.times.map { generate_attachment }
            attachments = get(:attachments)

            set(:expect_properties,
              :post => {
                :attachments => attachments.concat(new_attachments).map { |a|
                  a = a.dup
                  a.merge!(:digest => hex_digest(a[:data]), :size => a[:data].size)
                  a.delete(:data)
                  a
                }
              })

            post = get(:post)
            set(:create_post_version_response) do
              create_post_version.call(post.merge(:attachments => attachments.map { |attachment|
                TentD::Utils::Hash.slice(attachment, :name, :category, :content_type).merge(:digest => hex_digest(attachment[:data]))
              }), get(:client), :keep_attachments => true, :new_attachments => new_attachments)
            end
          end
        end

        context "new attachments" do
          setup do
            attachments = 3.times.map { generate_attachment }

            set(:expect_properties,
              :post => {
                :attachments => attachments.map { |a|
                  a = a.dup
                  a.merge!(:digest => hex_digest(a[:data]), :size => a[:data].size)
                  a.delete(:data)
                  a
                }
              })

            post = get(:post)
            set(:create_post_version_response) do
              create_post_version.call(post, get(:client), :attachments => attachments)
            end
          end

          behaves_as(:create_post_version)
        end

        context "discard attachments" do
          setup do
            set(:expect_properties_absent, '/post/attachments')

            post = get(:post).dup
            post.delete(:attachments)
            set(:create_post_version_response) do
              create_post_version.call(post, get(:client))
            end
          end

          behaves_as(:create_post_version)
        end
      end

      context "when post has mentions" do
        setup do
          post = create_post.call(:public => false, :mentions => [{ :entity => "https://e.example.org", :type => "https://tent.io/types/status/v0#", :post => "some-post-identifier" }])
          set(:post, post)
        end

        context "version has mentions" do
          setup do
            post = get(:post).dup
            post[:mentions] = [{
              :entity => "https://a.example.com",
              :type => "https://tent.example.org/types/fictitious/v0#",
              :post => "some-other-post-identifier"
            }]

            set(:create_post_version_response) do
              create_post_version.call(post, get(:client))
            end
          end

          behaves_as(:create_post_version)
        end

        context "version doesn't have mentions" do
          setup do
            post = get(:post).dup
            post.delete(:mentions)

            set(:create_post_version_response) do
              create_post_version.call(post, get(:client))
            end
          end

          behaves_as(:create_post_version)
        end
      end
    end

  end

  TentValidator.validators << PostVersionsValidator
end
