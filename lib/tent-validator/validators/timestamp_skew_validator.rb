module TentValidator
  class TimestampSkewValidator < TentValidator::Spec

    require 'tent-validator/validators/support/post_generators'
    include Support::PostGenerators

    require 'tent-validator/validators/support/app_post_generators'
    include Support::AppPostGenerators

    require 'tent-validator/validators/support/oauth'
    include Support::OAuth

    describe "POST post with skewed timestamp" do
      setup do
        authenticate_with_permissions(:write_types => %w[ https://tent.io/types/status/v0 ])
      end

      describe "" do

      expect_response(:status => 401) do
        expect_headers(
          "WWW-Authenticate" => %r{Hawk .+tsm=(["'])[^\1]+\1}
        )

        client = get(:client)
        client.options[:ts_skew_retry_enabled] = false
        client.ts_skew = 90

        client.post.create(generate_status_post)
      end

      end
    end
  end

  TentValidator.validators << TimestampSkewValidator
end
