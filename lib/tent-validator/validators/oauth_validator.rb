module TentValidator
  class OAuthValidator < TentValidator::Spec

    require 'tent-validator/validators/support/app_post_generators'
    include Support::AppPostGenerators

    SetupFailure = Class.new(StandardError)

    def create_app
      client = clients(:no_auth)
      res = client.post.create(generate_app_post)
      raise SetupFailure.new("Could not create app! #{res.status}: #{res.body.inspect}") unless res.success?
      set(:app, res.body['post'])

      links = TentClient::LinkHeader.parse(res.headers['Link'].to_s).links
      credentials_url = links.find { |link| link[:rel] == 'https://tent.io/rels/credentials' }
      if credentials_url
        credentials_url = credentials_url.uri
        res = client.http.get(credentials_url)
        raise SetupFailure.new("Could not fetch app credentials! #{res.status}: #{res.body.inspect}") unless res.success?
        set(:app_credentials, :id => res.body['post']['id'],
                              :hawk_key => res.body['post']['content']['hawk_key'],
                              :hawk_algorithm => res.body['post']['content']['hawk_algorithm'])
      else
        raise SetupFailure.new("App credentials not linked! #{res.status}: #{res.headers.inspect}")
      end
    end

    describe "oauth_auth", :before => :create_app do
      # server should be in test mode (no user confirmation page)
      expect_response(:status => 302) do
        expect_headers(:Location => %r{\bcode=.+\b})

        client = clients(:no_auth)
        res = client.http.get(client.oauth_redirect_uri(:client_id => get(:app)['id']))

        set(:oauth_redirect_uri, res.headers[:Location].to_s)

        res
      end

      describe "oauth_token" do
        expect_response(:status => 200) do
          token_code = parse_params(URI(get(:oauth_redirect_uri)).query)['code']

          expect_properties(
            :access_token => /\A.+\Z/,
            :hawk_key => /\A.+\Z/,
            :hawk_algorithm => 'sha256',
            :token_type => 'https://tent.io/oauth/hawk-token'
          )

          client = clients(:custom, get(:app_credentials))
          client.oauth_token_exchange(:code => token_code)
        end
      end
    end

  end

  TentValidator.validators << OAuthValidator
end
