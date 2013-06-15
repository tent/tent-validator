module TentValidator
  module WithoutAuthentication

    class RelationshipValidator < TentValidator::Spec

      describe "Relationship initialization" do
        expect_response(:status => 200, :schema => :data) do
          expect_schema(:post, '/post')
          expect_schema(:post_meta, '/post/content')

          remote_entity = TentValidator.remote_entity_uri
          client = TentClient.new(remote_entity)

          TentClient::Discovery.discover(client, remote_entity, :return_response => true) || Faraday::Response.new({})
        end

        expect_response(:status => 200, :schema => :data) do
          expect_schema(:post, '/post')
          expect_schema(:post_relationship, '/post/content')

          ##
          # Create user on local server
          user = TentD::Model::User.generate

          ##
          # Create relationship#initial post
          relationship = TentD::Model::Relationship.create_initial(user, TentValidator.remote_entity_uri.to_s)
          relationship_data = relationship.post.as_json

          expect_headers('Content-Type' => TentD::API::POST_CONTENT_TYPE % relationship.post.type)
          expect_properties(:post => relationship_data)

          ##
          # Create credentials post which mentions relationship#initial
          credentials_post = relationship.credentials_post

          expect_headers(
            'Link' => %r{rel=['"]#{Regexp.escape("https://tent.io/rels/credentials")}['"]}
          )

          ##
          # Setup asyc request expectation for relationship# post
          expect_async_request(
            :method => "PUT",
            :path => %r{\A/posts/#{Regexp.escape(URI.encode_www_form_component(TentValidator.remote_entity_uri))}/[^/]+\Z},
            :headers => {
              'Content-Type' => TentD::API::POST_CONTENT_TYPE % %(https://tent.io/types/relationship/v0#)
            }
          ) do
            expect_schema(:post)
            expect_headers(
              'Content-Type' => %r{\brel=['"]#{Regexp.escape("https://tent.io/rels/notification")}['"]}
            )
          end.expect_response(:status => 200, :schema => :data) do
            expect_schema(:post, '/post')
            expect_headers(
              'Content-Type' => TentD::API::POST_CONTENT_TYPE % %(https://tent.io/types/relationship/v0#)
            )
          end

          ##
          # Start watching local requests
          watch_local_requests(true, user.id)

          ##
          # Send relationship#initial notification to remote server
          #   - with link header with signed (bewit) url to credentials post
          res = clients(:no_auth, :server => :remote).post.update(relationship_data[:entity], relationship_data[:id], relationship_data, {}, :notification => true) do |request|
            url = TentD::Utils.expand_uri_template(
              user.preferred_server['urls']['post'],
              :entity => user.entity,
              :post => credentials_post.public_id
            )
            link = %(<#{TentD::Utils.sign_url(user.server_credentials, url)}>; rel="https://tent.io/rels/credentials")
            request.headers['Link'] ? request.headers['Link'] << ", #{link}" : request.headers['Link'] = link
          end

          ##
          # Expect discovery
          expect_request(
            :method => :head,
            :path => "/"
          )
          expect_request(
            :method => :get,
            :path => "/posts/#{URI.encode_www_form_component(user.entity)}/#{user.meta_post.public_id}",
            :headers => {
              "Accept" => Regexp.new("\\A" + Regexp.escape(TentD::API::POST_CONTENT_MIME))
            }
          ).expect_response(:status => 200, :schema => :data) do
            expect_properties(:post => user.meta_post.as_json)
          end

          ##
          # Expect credentials post to be fetched
          expect_request(
            :method => :get,
            :path => "/posts/#{URI.encode_www_form_component(user.entity)}/#{credentials_post.public_id}",
            :headers => {
              "Accept" => Regexp.new("\\A" + Regexp.escape(TentD::API::POST_CONTENT_MIME))
            }
          ).expect_response(:status => 200, :schema => :data) do
            expect_properties(:post => credentials_post.as_json)
          end

          ##
          # Expect relationship#initial post to be fetched
          expect_request(
            :method => :get,
            :path => "/posts/#{URI.encode_www_form_component(user.entity)}/#{relationship.post.public_id}",
            :headers => {
              "Accept" => Regexp.new("\\A" + Regexp.escape(TentD::API::POST_CONTENT_MIME))
            }
          ) do
            expect_headers('Authorization' => %r{\bHawk\b})
            expect_headers('Authorization' => %r{id=['"]#{credentials_post.public_id}['"]})
          end.expect_response(:status => 200, :schema => :data) do
            expect_properties(:post => relationship_data)
          end

          ##
          # Stop watching local requests
          watch_local_requests(false, user.id)

          ##
          # Cache credentials link for next response expectation
          links = TentClient::LinkHeader.parse(res.headers['Link'].to_s).links
          credentials_url = links.find { |link| link[:rel] == 'https://tent.io/rels/credentials' }
          set(:credentials_url, credentials_url.uri) if credentials_url

          ##
          # Validate response
          res
        end

        ##
        # Fetch credentials post from target server
        expect_response(:status => 200, :schema => :data) do
          expect_schema(:post, '/post')
          expect_schema(:post_credentials, '/post/content')

          if url = get(:credentials_url)
            res = clients(:no_auth).http.get(url)

            if res.status == 200 && (Hash === res.body)
              set(:credentials_post, TentD::Utils::Hash.symbolize_keys(res.body)[:post])
            end

            res
          else
            Faraday::Response.new({})
          end
        end

        ##
        # Fetch target relationship post via credentials post mention
        expect_response(:status => 200, :schema => :data) do
          expect_schema(:post, '/post')
          expect_schema(:post_relationship, '/post/content')

          if credentials_post = get(:credentials_post)
            mention = credentials_post[:mentions].to_a.find { |m|
              TentClient::TentType.new(m[:type]).base == %(https://tent.io/types/relationship)
            }

            unless mention
              return Faraday::Response.new({})
            end

            credentials = {
              :id => credentials_post[:id],
              :hawk_key => credentials_post[:content][:hawk_key],
              :hawk_algorithm => credentials_post[:content][:hawk_algorithm]
            }
            res = clients(:custom, credentials).post.get(credentials_post[:entity], mention[:post])

            if res.status == 200
              set(:relationship_post, TentD::Utils::Hash.symbolize_keys(res.body)[:post])
            end

            res
          else
            Faraday::Response.new({})
          end
        end
      end

    end

  end

  TentValidator.validators << WithoutAuthentication::RelationshipValidator
end
