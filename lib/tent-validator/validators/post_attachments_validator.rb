module TentValidator
  class PostAttachmentsValidator < TentValidator::Spec
    SetupFailure = Class.new(StandardError)

    require 'tent-validator/validators/support/post_generators'
    class << self
      include Support::PostGenerators
    end
    include Support::PostGenerators

    require 'tent-validator/validators/support/app_post_generators'
    include Support::AppPostGenerators

    require 'tent-validator/validators/support/oauth'
    include Support::OAuth

    create_post_with_attachments = lambda do |opts|
      attachments = 3.times.map { generate_attachment }
      data = generate_status_post(opts[:public])
      res = clients(:app).post.create(data, params = {}, :attachments => attachments.map(&:dup))

      res_validation = ApiValidator::Json.new(
        :attachments => attachments.map { |a|
          a = a.dup
          a.merge!(:digest => hex_digest(a[:data]), :size => a[:data].size)
          a.delete(:data)
          a
        }
      ).validate(res)
      raise SetupFailure.new("Failed to create post with attachments! #{res.status}\n\t#{Yajl::Encoder.encode(res_validation[:diff])}\n\t#{res.body}") unless res_validation[:valid]

      [TentD::Utils::Hash.symbolize_keys(res.body), attachments]
    end

    context "when public" do
      setup do
        post, attachments = create_post_with_attachments.call(:public => true)

        set(:post, post)
        set(:attachments, attachments)
      end

      describe "post_attachment" do
        expect_response(:status => 302) do
          post = get(:post)
          attachment = get(:attachments)[1]

          expect_headers(
            'Location' => Regexp.new(Regexp.escape(hex_digest(attachment[:data])))
          )

          res = clients(:no_auth).http.get(:post_attachment,
            :entity => post[:entity],
            :post => post[:id],
            :name => attachment[:name],
            :version => 'latest'
          )

          set(:attachment_url, res.headers['Location'])

          res
        end

        expect_response(:status => 200) do
          post = get(:post)
          attachment = get(:attachments)[1]

          expect_headers(
            'Content-Type' => attachment[:content_type],
            'Content-Length' => attachment[:data].size.to_s
          )

          expect_body(attachment[:data])

          if (url = get(:attachment_url)) && url =~ /\Ahttp/
            clients(:no_auth).http.get(url)
          else
            Faraday::Response.new(:env => {})
          end
        end
      end

      describe "attachment" do
        expect_response(:status => 200) do
          post = get(:post)
          attachment = get(:attachments).last

          expect_headers(
            'Content-Type' => attachment[:content_type],
            'Content-Length' => attachment[:data].size.to_s
          )

          expect_body(attachment[:data])

          clients(:no_auth).http.get(:attachment, :entity => post[:entity], :digest => hex_digest(attachment[:data]))
        end
      end
    end

    context "when private" do
      setup do
        post, attachments = create_post_with_attachments.call(:public => false)

        set(:post, post)
        set(:attachments, attachments)
      end

      context "without auth" do
        describe "post_attachment" do
          expect_response(:status => 404) do
            post = get(:post)
            attachment = get(:attachments)[1]

            clients(:no_auth).http.get(:post_attachment,
              :entity => post[:entity],
              :post => post[:id],
              :name => attachment[:name],
              :version => 'latest'
            )
          end
        end

        describe "attachment" do
          expect_response(:status => 404) do
            post = get(:post)
            attachment = get(:attachments).last

            clients(:no_auth).http.get(:attachment, :entity => post[:entity], :digest => hex_digest(attachment[:data]))
          end
        end
      end

      context "with auth" do
        context "when unauthorized" do
          setup do
            authenticate_with_permissions(:read_post_types => [])
          end

          describe "post_attachment" do
            expect_response(:status => 403) do
              post = get(:post)
              attachment = get(:attachments)[1]

              get(:client).http.get(:post_attachment,
                :entity => post[:entity],
                :post => post[:id],
                :name => attachment[:name],
                :version => 'latest'
              )
            end
          end

          describe "attachment" do
            expect_response(:status => 403) do
              post = get(:post)
              attachment = get(:attachments).last

              get(:client).http.get(:attachment, :entity => post[:entity], :digest => hex_digest(attachment[:data]))
            end
          end
        end

        context "when authorized with limited access" do
          setup do
            authenticate_with_permissions(:read_post_types => [get(:post)[:type]])
          end

          describe "post_attachment" do
            expect_response(:status => 302) do
              post = get(:post)
              attachment = get(:attachments)[1]

              expect_headers(
                'Location' => Regexp.new(Regexp.escape(hex_digest(attachment[:data])))
              )

              res = get(:client).http.get(:post_attachment,
                :entity => post[:entity],
                :post => post[:id],
                :name => attachment[:name],
                :version => 'latest'
              )

              set(:attachment_url, res.headers['Location'])

              res
            end

            expect_response(:status => 200) do
              post = get(:post)
              attachment = get(:attachments)[1]

              expect_headers(
                'Content-Type' => attachment[:content_type],
                'Content-Length' => attachment[:data].size.to_s
              )

              expect_body(attachment[:data])

              if (url = get(:attachment_url)) && url =~ /\Ahttp/
                get(:client).http.get(url)
              else
                Faraday::Response.new(:env => {})
              end
            end
          end

          describe "attachment" do
            expect_response(:status => 200) do
              post = get(:post)
              attachment = get(:attachments).last

              expect_headers(
                'Content-Type' => attachment[:content_type],
                'Content-Length' => attachment[:data].size.to_s
              )

              expect_body(attachment[:data])

              clients(:app).http.get(:attachment, :entity => post[:entity], :digest => hex_digest(attachment[:data]))
            end
          end
        end

        context "when authorized with full access" do
          setup do
            set(:client, clients(:app))
          end

          describe "post_attachment" do
            expect_response(:status => 302) do
              post = get(:post)
              attachment = get(:attachments)[1]

              expect_headers(
                'Location' => Regexp.new(Regexp.escape(hex_digest(attachment[:data])))
              )

              res = get(:client).http.get(:post_attachment,
                :entity => post[:entity],
                :post => post[:id],
                :name => attachment[:name],
                :version => 'latest'
              )

              set(:attachment_url, res.headers['Location'])

              res
            end

            expect_response(:status => 200) do
              post = get(:post)
              attachment = get(:attachments)[1]

              expect_headers(
                'Content-Type' => attachment[:content_type],
                'Content-Length' => attachment[:data].size.to_s
              )

              expect_body(attachment[:data])

              if (url = get(:attachment_url)) && url =~ /\Ahttp/
                get(:client).http.get(url)
              else
                Faraday::Response.new(:env => {})
              end
            end
          end

          describe "attachment" do
            expect_response(:status => 200) do
              post = get(:post)
              attachment = get(:attachments).last

              expect_headers(
                'Content-Type' => attachment[:content_type],
                'Content-Length' => attachment[:data].size.to_s
              )

              expect_body(attachment[:data])

              clients(:app).http.get(:attachment, :entity => post[:entity], :digest => hex_digest(attachment[:data]))
            end
          end
        end
      end
    end

  end

  TentValidator.validators << PostAttachmentsValidator
end
