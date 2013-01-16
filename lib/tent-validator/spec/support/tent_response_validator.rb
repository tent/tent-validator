module TentValidator
  module Spec
    class TentResponseValidator < ResponseValidator
      register :tent

      validate_headers do
        expect_valid_cors_headers
        expect_header('Content-Type', /\A#{Regexp.escape(TentD::API::MEDIA_TYPE)}/)
      end

      private

      def expect_valid_cors_headers
        expect_header('Access-Control-Allow-Origin', '*')
        expect_header('Access-Control-Allow-Methods', %w( GET POST HEAD PUT DELETE PATCH OPTIONS ), :split => /[^a-z]+/i)
        expect_header('Access-Control-Allow-Headers', %w( Content-Type Authorization ), :split => /[^a-z]+/i)
        expect_header('Access-Control-Expose-Headers', %w( Count Link ), :split => /[^a-z]+/i)
      end
    end
  end
end
