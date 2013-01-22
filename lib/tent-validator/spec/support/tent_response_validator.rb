module TentValidator
  module Spec
    class TentHeadResponseValidator < ResponseValidator
      register :tent_head

      validate_headers do
        expect_header('Content-Type', /\A#{Regexp.escape(TentD::API::MEDIA_TYPE)}/)
        expect_header('Count', /\A\d+\Z/)
        expect_header('Content-Length', /\A\d+\Z/)
      end
    end

    class TentResponseValidator < ResponseValidator
      register :tent

      validate_headers do
        expect_header('Content-Type', /\A#{Regexp.escape(TentD::API::MEDIA_TYPE)}/)
      end
    end

    class TentCorsResponseValidator < ResponseValidator
      register :tent_cors

      validate_headers do
        expect_valid_cors_headers
      end

      private

      def expect_valid_cors_headers
        expect_header('Access-Control-Allow-Origin', '*')
        expect_header('Access-Control-Allow-Methods', %w( GET POST HEAD PUT DELETE PATCH OPTIONS ), :split => /[^a-z-]+/i)
        expect_header('Access-Control-Allow-Headers', %w( Content-Type Authorization ), :split => /[^a-z-]+/i)
        expect_header('Access-Control-Expose-Headers', %w( Count Link ), :split => /[^a-z-]+/i)
      end
    end
  end
end
