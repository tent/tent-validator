module TentValidator
  module WithoutAuthentication

    class RelationshipValidator < TentValidator::Spec

      describe "Relationship initialization" do
        expect_response(:status => 200, :schema => :data) do
          expect_schema(:post, '/post')

          ##
          # Create user on local server
          user = TentD::Model::User.generate

          ##
          # Create relationship#initial post
          relationship_post = TentD::Model::Relationship.create_initial(user, TentValidator.remote_entity_uri.to_s)
          relationship_data = relationship_post.as_json

          expect_headers('Content-Type' => TentD::API::POST_CONTENT_TYPE % relationship_post.type)
          expect_properties(:post => relationship_data)

          ##
          # Create credentials post which mentions relationship#initial
          credentials_post = TentD::Model::Credentials.generate(user, relationship_post)

          expect_headers(
            'Link' => %r{rel=['"]#{Regexp.escape("https://tent.io/rels/credentials")}['"]}
          )

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
              "Accept" => TentD::API::POST_CONTENT_TYPE % user.meta_post.type
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
              "Accept" => TentD::API::POST_CONTENT_TYPE % credentials_post.type
            }
          ).expect_response(:status => 200, :schema => :data) do
            expect_properties(:post => credentials_post.as_json)
          end

          ##
          # Expect relationship#initial post to be fetched
          expect_request(
            :method => :get,
            :path => "/posts/#{URI.encode_www_form_component(user.entity)}/#{relationship_post.public_id}",
            :headers => {
              "Accept" => TentD::API::POST_CONTENT_TYPE % relationship_post.type
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
          # Validate response
          res
        end
      end

    end

  end

  TentValidator.validators << WithoutAuthentication::RelationshipValidator
end
