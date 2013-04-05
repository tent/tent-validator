require 'tent-validator/validators/support/tent_header_expectation'
require 'tent-validator/validators/support/post_header_expectation'
require 'tent-validator/validators/support/error_header_expectation'
require 'tent-validator/validators/support/tent_schemas'

module TentValidator
  class PostValidator < Validator

    shared_example :new_post do
      context "with invalid attributes" do
        context "when extra field in content" do
          expect_response(:headers => :error, :status => 400, :schema => :error) do
            data = get(:post)
            data[:content][:extra_member] = "I shouldn't be here!"
            clients(:no_auth, :server => :remote).post.create(data)
          end
        end

        invalid_member_expectation = proc do |path, property|
          expect_response(:headers => :error, :status => 400, :schema => :error) do
            data = get(:post)
            pointer = JsonPointer.new(data, path, :symbolize_keys => true)
            pointer.value = invalid_value(property['type'], property['format'])
            clients(:no_auth, :server => :remote).post.create(data)
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
          TentValidator::Schemas[get(:content_schema)]["properties"].each_pair do |name, property|
            invalid_member_expectation.call("/content/#{name}", property)
          end
        end

        context "when post member is wrong type" do
          properties = TentValidator::Schemas[:post]["properties"]
          %w( published_at version mentions licenses content attachments app permissions ).each do |name|
            invalid_member_expectation.call("/#{name}", properties[name])
          end
        end

        context "when extra post member" do
          expect_response(:headers => :error, :status => 400, :schema => :error) do
            data = get(:post)
            data[:extra_member] = "I shouldn't be here!"
            clients(:no_auth, :server => :remote).post.create(data)
          end
        end

        context "when content is wrong type" do
          expect_response(:headers => :error, :status => 400, :schema => :error) do
            data = get(:post)
            data[:content] = "I should be an object"
            clients(:no_auth, :server => :remote).post.create(data)
          end

          expect_response(:headers => :error, :status => 400, :schema => :error) do
            data = get(:post)
            data[:content] = ["My parent should be an object!"]
            clients(:no_auth, :server => :remote).post.create(data)
          end

          expect_response(:headers => :error, :status => 400, :schema => :error) do
            data = get(:post)
            data[:content] = true
            clients(:no_auth, :server => :remote).post.create(data)
          end
        end
      end

      context "without request body" do
        expect_response(:headers => :error, :status => 400, :schema => :error) do
          clients(:no_auth, :server => :remote).post.create(nil) do |request|
            request.headers['Content-Type'] = TentD::API::CONTENT_TYPE % 'https://tent.io/types/app/v0#'
          end
        end
      end

      context "when request body is wrong type" do
        expect_response(:headers => :error, :status => 400, :schema => :error) do
          clients(:no_auth, :server => :remote).post.create("I should be an object") do |request|
            request.headers['Content-Type'] = TentD::API::CONTENT_TYPE % 'https://tent.io/types/app/v0#'
          end
        end
      end

      context "with invalid content-type header" do
        data = get(:post)
        expect_response(:headers => :error, :status => 415, :schema => :error) do
          clients(:no_auth, :server => :remote).post.create(data) do |request|
            request.headers['Content-Type'] = 'application/json'
          end
        end
      end
    end

  end

end
