module TentValidator
  class RequestProxyValidator < TentValidator::Spec
    require 'tent-validator/validators/support/post_generators'
    include Support::PostGenerators

    # TODO:
    # - refactor: make cached post and uncached post different posts

    describe "GET post when foreign entity" do
      shared_example :get_post_via_proxy do
        expect_response(:status => 200, :schema => :data) do
          post, user = get(:post), get(:user)
          cache_control = get(:cache_control)

          expect_properties(:post => post)

          watch_local_requests(true, user.id)

          res = catch_faraday_exceptions("Proxied request failed") do
            get(:client).post.get(post[:entity], post[:id]) do |request|
              if cache_control
                request.headers['Cache-Control'] = cache_control
              end
            end
          end

          watch_local_requests(true, user.id)

          # Expect discovery (no relationship exists)
          expect_request(
            :method => :head,
            :url => %r{\A#{Regexp.escape(user.entity)}},
            :path => "/"
          )
          expect_request(
            :method => :get,
            :url => %r{\A#{Regexp.escape(user.entity)}},
            :path => "/posts/#{URI.encode_www_form_component(user.entity)}/#{user.meta_post.public_id}",
            :headers => {
              "Accept" => Regexp.new("\\A" + Regexp.escape(TentD::API::POST_CONTENT_MIME))
            }
          ).expect_response(:status => 200, :schema => :data) do
            expect_properties(:post => user.meta_post.as_json)
          end

          # Expect post to be fetched
          expect_request(
            :method => :get,
            :url => %r{\A#{Regexp.escape(user.entity)}},
            :path => "/posts/#{URI.encode_www_form_component(user.entity)}/#{post[:id]}",
            :headers => {
              "Accept" => Regexp.new("\\A" + Regexp.escape(TentD::API::POST_CONTENT_MIME))
            }
          ).expect_response(:status => 200, :schema => :data) do
            expect_properties(:post => post)
          end

          res
        end
      end

      shared_example :get_post_without_proxy do
        expect_response(:status => 200, :schema => :data) do
          post, user = get(:post), get(:user)
          cache_control = get(:cache_control)

          expect_properties(:post => post)

          catch_faraday_exceptions("Proxied request failed") do
            get(:client).post.get(post[:entity], post[:id]) do |request|
              request.headers['Cache-Control'] = cache_control
            end
          end
        end
      end

      shared_example :get_post_not_found do
        expect_response(:status => 404, :schema => :error) do
          post = get(:post)
          catch_faraday_exceptions("Request failed") do
            get(:client).post.get(post[:entity], post[:id])
          end
        end
      end

      setup do
        set(:user, TentD::Model::User.generate)
      end

      expect_response(:status => 200, :schema => :data) do
        data = generate_status_post

        res = clients(:app_auth, :server => :local, :user => get(:user)).post.create(data)

        data.delete(:permissions)
        expect_properties(:post => data)

        res
      end.after do |response, results|
        if !results.any? { |r| !r[:valid] }
          set(:post, TentD::Utils::Hash.symbolize_keys(response.body['post']))
        else
          raise SetupFailure.new("Failed to create post on local server", response, results)
        end
      end

      context "when post not cached" do
        context "when app authorized" do
          setup do
            set(:client, clients(:app_auth))
          end

          context "when `Cache-Control: no-cache`" do
            setup do
              set(:cache_control, 'no-cache')
            end

            behaves_as(:get_post_via_proxy)
          end

          context "when `Cache-Control: proxy-if-miss`" do
            setup do
              set(:cache_control, 'proxy-if-miss')
            end

            behaves_as(:get_post_via_proxy)
          end

          context "when `Cache-Control: only-if-cached` (default)" do
            expect_response(:status => 404, :schema => :error) do
              post = get(:post)
              catch_faraday_exceptions("Request failed") do
                get(:client).post.get(post[:entity], post[:id]) do |request|
                  request.headers['Cache-Control'] = 'only-if-cached'
                end
              end
            end

            expect_response(:status => 404, :schema => :error) do
              post = get(:post)
              catch_faraday_exceptions("Request failed") do
                get(:client).post.get(post[:entity], post[:id])
              end
            end
          end
        end

        context "when authorization is not an app" do
          setup do
            set(:client, clients(:app))
          end

          expect_response(:status => 404, :schema => :error) do
            post = get(:post)
            catch_faraday_exceptions("Request failed") do
              get(:client).post.get(post[:entity], post[:id])
            end
          end

          context "when `Cache-Control: no-cache`" do
            expect_response(:status => 404, :schema => :error) do
              post = get(:post)
              catch_faraday_exceptions("Request failed") do
                get(:client).post.get(post[:entity], post[:id]) do |request|
                  request.headers['Cache-Control'] = 'only-if-cached'
                end
              end
            end
          end
        end

        context "without authentication" do
          setup do
            set(:client, clients(:no_auth))
          end

          expect_response(:status => 404, :schema => :error) do
            post = get(:post)
            catch_faraday_exceptions("Request failed") do
              get(:client).post.get(post[:entity], post[:id])
            end
          end

          context "when `Cache-Control: no-cache`" do
            expect_response(:status => 404, :schema => :error) do
              post = get(:post)
              catch_faraday_exceptions("Request failed") do
                get(:client).post.get(post[:entity], post[:id]) do |request|
                  request.headers['Cache-Control'] = 'only-if-cached'
                end
              end
            end
          end
        end
      end

      context "when post cached" do
        expect_response(:status => 200, :schema => :data) do
          post = get(:post)
          clients(:app_auth).post.update(post[:entity], post[:id], post, {}, :import => true)
        end.after do |response, results|
          if results.any? { |r| !r[:valid] }
            raise SetupFailure.new("Failed to deliver post notification on remote server", response, results)
          end
        end

        context "when app authorized" do
          setup do
            set(:client, clients(:app_auth))
          end

          context "when `Cache-Control: no-cache`" do
            setup do
              set(:cache_control, 'no-cache')
            end

            behaves_as(:get_post_via_proxy)
          end

          context "when `Cache-Control: proxy-if-miss`" do
            setup do
              set(:cache_control, 'proxy-if-miss')
            end

            behaves_as(:get_post_without_proxy)
          end

          context "when `Cache-Control: only-if-cached` (default)" do
            setup do
              set(:cache_control, 'only-if-cached')
            end

            behaves_as(:get_post_without_proxy)
          end
        end

        context "when authorization is not an app" do
          setup do
            set(:client, clients(:app))
          end

          behaves_as(:get_post_not_found)
        end

        context "when not authenticated" do
          setup do
            set(:client, clients(:no_auth))
          end

          behaves_as(:get_post_not_found)
        end
      end
    end

    describe "GET posts_feed refs" do
      setup do
        set(:user, TentD::Model::User.generate)
      end

      expect_response(:status => 200, :schema => :data) do
        data = generate_status_post

        res = clients(:app_auth, :server => :local, :user => get(:user)).post.create(data)

        data.delete(:permissions)
        expect_properties(:post => data)

        res
      end.after do |response, results|
        if !results.any? { |r| !r[:valid] }
          post = TentD::Utils::Hash.symbolize_keys(response.body['post'])
          post[:received_at] = Spec.property_absent
          post[:version][:received_at] = Spec.property_absent
          set(:reffed_post, post)
        else
          raise SetupFailure.new("Failed to create post on local server", response, results)
        end
      end

      expect_response(:status => 200, :schema => :data) do
        reffed_post = get(:reffed_post)

        data = generate_status_post

        data[:refs] = [{ :entity => reffed_post[:entity], :post => reffed_post[:id], :type => reffed_post[:type] }]

        res = clients(:app_auth).post.create(data)

        data.delete(:permissions)
        expect_properties(:post => data)

        res
      end.after do |response, results|
        if !results.any? { |r| !r[:valid] }
          set(:post, TentD::Utils::Hash.symbolize_keys(response.body['post']))
        else
          raise SetupFailure.new("Failed to create post on remote server", response, results)
        end
      end

      # fetch feed with proxied reffed post
      shared_example :fetch_via_proxy do
        expect_response(:status => 200, :schema => :data) do
          reffed_post = get(:reffed_post)
          user = get(:user)
          post = get(:post)
          cache_control = get(:cache_control)

          unless get(:is_app)
            post = TentD::Utils::Hash.deep_dup(post)
            post[:received_at] = property_absent
            post[:version][:received_at] = property_absent
          end

          expect_properties(:posts => [post])
          expect_properties(:refs => [reffed_post])

          watch_local_requests(true, user.id)

          res = get(:client).post.list(:limit => 1, :max_refs => 1) do |request|
            if cache_control
              request.headers['Cache-Control'] = cache_control
            end
          end

          watch_local_requests(false, user.id)

          # Expect discovery (no relationship exists)
          expect_request(
            :method => :head,
            :url => %r{\A#{Regexp.escape(user.entity)}},
            :path => "/"
          )
          expect_request(
            :method => :get,
            :url => %r{\A#{Regexp.escape(user.entity)}},
            :path => "/posts/#{URI.encode_www_form_component(user.entity)}/#{user.meta_post.public_id}",
            :headers => {
              "Accept" => Regexp.new("\\A" + Regexp.escape(TentD::API::POST_CONTENT_MIME))
            }
          ).expect_response(:status => 200, :schema => :data) do
            expect_properties(:post => user.meta_post.as_json)
          end

          # Expect post to be fetched
          expect_request(
            :method => :get,
            :url => %r{\A#{Regexp.escape(user.entity)}},
            :path => "/posts/#{URI.encode_www_form_component(user.entity)}/#{reffed_post[:id]}",
            :headers => {
              "Accept" => Regexp.new("\\A" + Regexp.escape(TentD::API::POST_CONTENT_MIME))
            }
          ).expect_response(:status => 200, :schema => :data) do
            expect_properties(:post => reffed_post)
          end

          res
        end
      end

      # fetch feed with cached reffed post
      shared_example :fetch_without_proxy do
        expect_response(:status => 200, :schema => :data) do
          reffed_post = get(:reffed_post)
          post = get(:post)
          cache_control = get(:cache_control)

          unless get(:is_app)
            post = TentD::Utils::Hash.deep_dup(post)
            post[:received_at] = property_absent
            post[:version][:received_at] = property_absent
          end

          reffed_post = TentD::Utils::Hash.deep_dup(reffed_post)
          reffed_post.delete(:received_at)
          reffed_post[:version].delete(:received_at)

          expect_properties(:posts => [post])
          expect_properties(:refs => [reffed_post])

          get(:client).post.list(:limit => 1, :max_refs => 1) do |request|
            if cache_control
              request.headers['Cache-Control'] = cache_control
            end
          end
        end
      end

      # fetch feed without proxying reffed post
      shared_example :fetch_no_refs do
        expect_response(:status => 200, :schema => :data) do
          reffed_post = get(:reffed_post)
          post = get(:post)
          cache_control = get(:cache_control)

          unless get(:is_app)
            post = TentD::Utils::Hash.deep_dup(post)
            post[:received_at] = property_absent
            post[:version][:received_at] = property_absent
          end

          expect_properties(:posts => [post])
          expect_properties(:refs => [])

          get(:client).post.list(:limit => 1, :max_refs => 1) do |request|
            if cache_control
              request.headers['Cache-Control'] = cache_control
            end
          end
        end
      end

      context "when not cached" do
        context "when authenticated" do
          context "when app authorized" do
            setup do
              set(:client, clients(:app_auth))
              set(:is_app, true)
            end

            context "with `Cache-Control: no-cache`" do
              setup do
                set(:cache_control, 'no-cache')
              end

              behaves_as(:fetch_via_proxy)
            end

            context "with `Cache-Control: proxy-if-miss`" do
              setup do
                set(:cache_control, 'proxy-if-miss')
              end

              behaves_as(:fetch_via_proxy)
            end

            context "with `Cache-Control: only-if-cached` (default)" do
              setup do
                set(:cache_control, 'only-if-cached')
              end

              behaves_as(:fetch_no_refs)
            end
          end

          context "when authorization is not an app" do
            setup do
              set(:client, clients(:app))
              set(:is_app, false)
            end

            context "with `Cache-Control: no-cache`" do
              setup do
                set(:cache_control, 'no-cache')
              end

              behaves_as(:fetch_no_refs)
            end

            context "with `Cache-Control: proxy-if-miss`" do
              setup do
                set(:cache_control, 'proxy-if-miss')
              end

              behaves_as(:fetch_no_refs)
            end

            context "with `Cache-Control: only-if-cached` (default)" do
              setup do
                set(:cache_control, 'only-if-cached')
              end

              behaves_as(:fetch_no_refs)
            end
          end
        end

        context "when not authenticated" do
          setup do
            set(:client, clients(:no_auth))
            set(:is_app, false)
          end

          context "with `Cache-Control: no-cache`" do
            setup do
              set(:cache_control, 'no-cache')
            end

            behaves_as(:fetch_no_refs)
          end

          context "with `Cache-Control: proxy-if-miss`" do
            setup do
              set(:cache_control, 'proxy-if-miss')
            end

            behaves_as(:fetch_no_refs)
          end

          context "with `Cache-Control: only-if-cached` (default)" do
            setup do
              set(:cache_control, 'only-if-cached')
            end

            behaves_as(:fetch_no_refs)
          end
        end
      end

      context "when cached" do
        expect_response(:status => 200, :schema => :data) do
          post = TentD::Utils::Hash.deep_dup(get(:reffed_post))
          received_at = get(:post)[:received_at] - 100
          post[:received_at] = received_at
          post[:version][:received_at] = received_at
          clients(:app_auth).post.update(post[:entity], post[:id], post, {}, :import => true)
        end.after do |response, results|
          if results.any? { |r| !r[:valid] }
            raise SetupFailure.new("Failed to deliver post notification on remote server", response, results)
          end
        end

        context "when authenticated" do
          context "when app authorized" do
            setup do
              set(:client, clients(:app_auth))
              set(:is_app, true)
            end

            context "with `Cache-Control: no-cache`" do
              setup do
                set(:cache_control, 'no-cache')
              end

              behaves_as(:fetch_via_proxy)
            end

            context "with `Cache-Control: proxy-if-miss`" do
              setup do
                set(:cache_control, 'proxy-if-miss')
              end

              behaves_as(:fetch_without_proxy)
            end

            context "with `Cache-Control: only-if-cached` (default)" do
              setup do
                set(:cache_control, 'only-if-cached')
              end

              behaves_as(:fetch_without_proxy)
            end
          end

          context "when authorization is not an app" do
            setup do
              set(:client, clients(:app))
              set(:is_app, false)
            end

            context "with `Cache-Control: no-cache`" do
              setup do
                set(:cache_control, 'no-cache')
              end

              behaves_as(:fetch_no_refs)
            end

            context "with `Cache-Control: proxy-if-miss`" do
              setup do
                set(:cache_control, 'proxy-if-miss')
              end

              behaves_as(:fetch_no_refs)
            end

            context "with `Cache-Control: only-if-cached` (default)" do
              setup do
                set(:cache_control, 'only-if-cached')
              end

              behaves_as(:fetch_no_refs)
            end
          end
        end

        context "when not authenticated" do
          setup do
            set(:client, clients(:no_auth))
            set(:is_app, false)
          end

          context "with `Cache-Control: no-cache`" do
            setup do
              set(:cache_control, 'no-cache')
            end

            behaves_as(:fetch_no_refs)
          end

          context "with `Cache-Control: proxy-if-miss`" do
            setup do
              set(:cache_control, 'proxy-if-miss')
            end

            behaves_as(:fetch_no_refs)
          end

          context "with `Cache-Control: only-if-cached` (default)" do
            setup do
              set(:cache_control, 'only-if-cached')
            end

            behaves_as(:fetch_no_refs)
          end
        end
      end
    end

  end

  TentValidator.validators << RequestProxyValidator
end
