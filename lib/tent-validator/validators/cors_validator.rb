module TentValidator

  class CorsValidator < TentValidator::Spec
    shared_example :cors do
      context "OPTIONS" do
        expect_response do
          expect_headers('Access-Control-Allow-Origin' => /\A.+\Z/)

          expect_headers('Access-Control-Allow-Methods' => proc { |response|
            header = response.headers['Access-Control-Allow-Methods']
            actual = header.split(/\s*,\s*/)
            expected = %w( GET HEAD POST PUT PATCH DELETE )

            if expected.any? { |v| !actual.include?(v) }
              (actual | expected).compact.join(', ')
            else
              header
            end
          })

          expect_headers('Access-Control-Allow-Headers' => proc { |response|
            header = response.headers['Access-Control-Allow-Headers']
            actual = header.to_s.split(/\s*,\s*/)
            expected = %w( Accept Content-Type Authorization Link Cache-Control If-Match If-None-Match )

            if expected.any? { |v| !actual.include?(v) }
              (actual | expected).compact.join(', ')
            else
              header
            end
          })
                         
          clients(:no_auth).http.options(get(:url), get(:params))
        end
      end

      get(:methods).each do |method|
        context "#{method}" do
          context "when invalid" do
            expect_response do
              expect_headers('Access-Control-Allow-Origin' => /\A.+\Z/)

              expect_headers('Access-Control-Expose-Headers' => proc { |response|
                header = response.headers['Access-Control-Expose-Headers']
                actual = header.to_s.split(/\s*,\s*/)
                expected = %w( Server-Authorization Link Count ETag WWW-Authenticate )

                if expected.any? { |v| !actual.include?(v) }
                  (actual | expected).compact.join(', ')
                else
                  header
                end
              })

              clients(:no_auth).http.send(method.downcase, get(:url), get(:params)) do |request|
                request.headers['Origin'] = 'http://example.com'
              end
            end
          end

          context "when valid" do
            # TODO
          end
        end
      end
    end

    describe "CORS Headers" do
      describe "post" do
        set(:url, :post)
        set(:params, :post => 'fake-post-id', :entity => 'fake-entity')
        set(:methods, %w( GET HEAD PUT ))

        behaves_as(:cors)
      end

      describe "posts_feed" do
        set(:url, :posts_feed)
        set(:params)
        set(:methods, %w( GET HEAD ))

        behaves_as(:cors)
      end

      describe "post_attachment" do
        set(:url, :post)
        set(:params, :post => 'fake-post-id', :entity => 'fake-entity', :name => 'attachment-name')
        set(:methods, %w( GET HEAD ))

        behaves_as(:cors)
      end

      describe "attachment" do
        set(:url, :post)
        set(:params, :entity => 'fake-entity', :digest => 'attachment-digest')
        set(:methods, %w( GET HEAD ))

        behaves_as(:cors)
      end

      describe "oauth_token" do
        set(:url, :oauth_token)
        set(:methods, %w( POST ))

        behaves_as(:cors)
      end

      describe "new_post" do
        set(:url, :new_post)
        set(:methods, %w( POST ))

        behaves_as(:cors)
      end

      describe "server_info" do
        set(:url, :server_info)
        set(:methods, %w( GET HEAD ))

        behaves_as(:cors)
      end

      describe "batch" do
        set(:url, :batch)
        set(:methods, %w( GET HEAD ))

        behaves_as(:cors)
      end
    end
  end

  TentValidator.validators << CorsValidator
end
