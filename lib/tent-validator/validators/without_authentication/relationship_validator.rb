require 'tent-validator/validators/support/tent_header_expectation'
require 'tent-validator/validators/support/post_header_expectation'
require 'tent-validator/validators/support/tent_schemas'

module TentValidator
  module WithoutAuthentication

    class RelationshipValidator < TentValidator::Spec

      describe "POST /posts" do
        context "without authentication" do

          context "when relationship initialization" do
            expect_response(:status => 204) do
              ##
              # Create user on local server
              user = TentD::Model::User.generate

              ##
              # Create relationship#initial post
              relationship_post = TentD::Model::Relationship.create_initial(user, TentValidator.remote_entity_uri.to_s)
              relationship_data = relationship_post.as_json

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
              # Send relationship post to remote server
              #   - set link header pointing to one-time signed link to credentials post
              res = clients(:no_auth, :server => :remote).post.create(relationship_data, {}, :notification => true) do |request|
                url = TentD::Utils.expand_uri_template(
                  user.preferred_server['urls']['post'],
                  :entity => user.entity,
                  :post => credentials_post.public_id
                )
                link = %(<#{url}>; rel="https://tent.io/rels/credentials")
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
              )

              ##
              # Expect credentials post to be fetched
              expect_request(
                :method => :get,
                :path => "/posts/#{URI.encode_www_form_component(user.entity)}/#{credentials_post.public_id}",
                :headers => {
                  "Accept" => TentD::API::POST_CONTENT_TYPE % credentials_post.type
                }
              )

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

    end

  end

  TentValidator.validators << WithoutAuthentication::RelationshipValidator
end
