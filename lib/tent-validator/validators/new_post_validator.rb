require 'tent-validator/validators/post_validator'

module TentValidator
  class PostValidator

    shared_example :new_post do
      context "with valid attributes" do
        valid_post_expectation = proc do |post, expected_post|
          expect_response(:headers => :tent, :status => 200, :schema => :data) do
            expect_headers(:post)
            expect_properties(:post => expected_post)
            expect_schema(:post, '/post')
            expect_schema(get(:content_schema), "/post/content")

            if attachments = get(:post_attachments)
              expect_properties(
                :post =>  {
                  :attachments => attachments.map { |a|
                    a = a.dup
                    a.merge!(:digest => hex_digest(a[:data]), :size => a[:data].size)
                    a.delete(:data)
                    a
                  }
                }
              )

              res = get(:client).post.create(post, {}, :attachments => attachments)
            else
              res = get(:client).post.create(post)
            end

            if Hash === res.body
              expect_properties(:post => { :version => { :id => generate_version_signature(res.body['post']) } })
            end

            res
          end
        end

        valid_post_expectation.call(get(:post), get(:post))

        context "when member set that should be ignored" do
          properties = ApiValidator::JsonSchemas[:post]["properties"]
          %w( /id /received_at /entity /original_entity /app /version/id /version/published_at /version/received_at ).each do |path|
            path_fragments = path.split('/')
            property_path = path_fragments[0] + path_fragments[1..-1].join('/properties/')
            property = JsonPointer.new(properties, property_path).value

            post = get(:post)
            pointer = JsonPointer.new(post, path, :symbolize_keys => true)
            pointer.value = valid_value(property['type'], property['format'])

            valid_post_expectation.call(post, get(:post))
          end
        end
      end

      context "with invalid attributes" do
        context "when extra field in content" do
          expect_response(:headers => :error, :status => 400, :schema => :error) do
            data = get(:post)
            data[:content][:extra_member] = "I shouldn't be here!"

            if attachments = get(:post_attachments)
              res = get(:client).post.create(data, {}, :attachments => attachments)
            else
              res = get(:client).post.create(data)
            end
          end
        end

        invalid_member_expectation = proc do |path, property|
          expect_response(:headers => :error, :status => 400, :schema => :error) do
            data = get(:post)
            pointer = JsonPointer.new(data, path, :symbolize_keys => true)
            pointer.value = invalid_value(property['type'], property['format'])

            if attachments = get(:post_attachments)
              res = get(:client).post.create(data, {}, :attachments => attachments)
            else
              res = get(:client).post.create(data)
            end
          end

          if property['type'] == 'object' && property['properties']
            property['properties'].each_pair do |name, property|
              invalid_member_expectation.call(path + "/#{name}", property)
            end
          end

          if property['type'] == 'array' && property['items']
            invalid_member_expectation.call(path + "/-", { 'type' => property['items']['type'], 'format' => property['items']['format'] })
          end
        end

        context "when content member is wrong type" do
          ApiValidator::JsonSchemas[get(:content_schema)]["properties"].each_pair do |name, property|
            invalid_member_expectation.call("/content/#{name}", property)
          end
        end

        context "when post member is wrong type" do
          properties = ApiValidator::JsonSchemas[:post]["properties"]
          %w( published_at version mentions licenses content attachments permissions ).each do |name|
            invalid_member_expectation.call("/#{name}", properties[name])
          end
        end

        context "when extra post member" do
          expect_response(:headers => :error, :status => 400, :schema => :error) do
            data = get(:post)
            data[:extra_member] = "I shouldn't be here!"

            if attachments = get(:post_attachments)
              res = get(:client).post.create(data, {}, :attachments => attachments)
            else
              res = get(:client).post.create(data)
            end
          end
        end

        context "when content is wrong type" do
          expect_response(:headers => :error, :status => 400, :schema => :error) do
            data = get(:post)
            data[:content] = "I should be an object"

            if attachments = get(:post_attachments)
              res = get(:client).post.create(data, {}, :attachments => attachments)
            else
              res = get(:client).post.create(data)
            end
          end

          expect_response(:headers => :error, :status => 400, :schema => :error) do
            data = get(:post)
            data[:content] = ["My parent should be an object!"]

            if attachments = get(:post_attachments)
              res = get(:client).post.create(data, {}, :attachments => attachments)
            else
              res = get(:client).post.create(data)
            end
          end

          expect_response(:headers => :error, :status => 400, :schema => :error) do
            data = get(:post)
            data[:content] = true

            if attachments = get(:post_attachments)
              res = get(:client).post.create(data, {}, :attachments => attachments)
            else
              res = get(:client).post.create(data)
            end
          end
        end
      end

      context "without request body" do
        expect_response(:headers => :error, :status => 400, :schema => :error) do
          get(:client).post.create(nil) do |request|
            request.headers['Content-Type'] = TentD::API::POST_CONTENT_TYPE % 'https://tent.io/types/app/v0#'
          end
        end
      end

      context "when request body is wrong type" do
        expect_response(:headers => :error, :status => 400, :schema => :error) do
          get(:client).post.create("I should be an object") do |request|
            request.headers['Content-Type'] = TentD::API::POST_CONTENT_TYPE % 'https://tent.io/types/app/v0#'
          end
        end
      end

      context "with invalid content-type header" do
        data = get(:post)
        expect_response(:headers => :error, :status => 415, :schema => :error) do
          get(:client).post.create(data) do |request|
            request.headers['Content-Type'] = 'application/json'
          end
        end
      end
    end

  end
end
