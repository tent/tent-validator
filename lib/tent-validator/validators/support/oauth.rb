module TentValidator
  module Support
    module OAuth

      def authenticate_with_permissions(options = {})
        # create app
        expect_response(:status => 200, :schema => :post) do
          data = generate_app_post
          data[:content][:post_types][:read] = options[:read_post_types].to_a
          data[:content][:post_types][:write] = options[:write_post_types].to_a
          data[:content][:scopes] = options[:scopes].to_a

          res = clients(:no_auth).post.create(data)

          links = TentClient::LinkHeader.parse(res.headers['Link']).links
          credentials_url = links.find { |link| link[:rel] == 'https://tent.io/rels/credentials' }.uri

          set(:limited_app, res.body)
          set(:limited_app_credentials_url, credentials_url)

          res
        end

        # fetch app credentials
        expect_response(:status => 200) do
          expect_properties(
            :id => /\A.+\Z/,
            :content => {
              :hawk_key => /\A.+\Z/,
              :hawk_algorithm => /\A.+\Z/
            }
          )

          res = clients(:no_auth).http.get(get(:limited_app_credentials_url))

          if res.success?
            set(:limited_app_credentials,
              :id => res.body['id'],
              :hawk_key => res.body['content']['hawk_key'],
              :hawk_algorithm => res.body['content']['hawk_algorithm']
            )
          end

          res
        end

        # authorize app
        expect_response(:status => 302) do
          expect_headers(:Location => %r{\bcode=.+\b})

          client = clients(:no_auth)
          res = client.http.get(client.oauth_redirect_uri(:client_id => get(:limited_app)['id']))

          set(:oauth_redirect_uri, res.headers[:Location].to_s)

          res
        end

        # token exchange
        expect_response(:status => 200) do
          token_code = parse_params(URI(get(:oauth_redirect_uri)).query)['code']

          expect_properties(
            :access_token => /\A.+\Z/,
            :hawk_key => /\A.+\Z/,
            :hawk_algorithm => 'sha256',
            :token_type => 'https://tent.io/oauth/hawk-token'
          )

          client = clients(:custom, get(:limited_app_credentials))
          res = client.oauth_token_exchange(:code => token_code)

          set(:limited_credentials,
            :id => res.body['access_token'],
            :hawk_key => res.body['hawk_key'],
            :hawk_algorithm => res.body['hawk_algorithm']
          )

          set(:client, clients(:custom, get(:limited_credentials)))

          res
        end
      end

    end
  end
end
