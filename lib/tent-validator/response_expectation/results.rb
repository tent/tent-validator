require 'tent-validator/mixins/deep_merge'

module TentValidator
  class ResponseExpectation

    class Results
      include Mixins::DeepMerge

      attr_reader :response, :results
      def initialize(response, results)
        @response, @results = response, results
      end

      def as_json(options = {})
        res = results.inject(Hash.new) do |memo, result|
          result = result.dup
          deep_merge!((memo[result.delete(:key)] ||= Hash.new), result)
          memo
        end

        {
          :expected => res,
          :actual => {
            :request_headers => response.env[:request_headers],
            :request_body => response.env[:request_body],
            :request_path => response.env[:url].path,
            :request_params => parse_params(response.env[:url]),
            :request_url => response.env[:url].to_s,
            :request_method => response.env[:method].to_s.upcase,

            :response_headers => response.headers,
            :response_body => response.body,
            :response_status => response.status
          }
        }
      end

      private

      def parse_params(uri)
        return unless uri.query
        uri.query.split('&').inject({}) do |params, part|
          key, value = part.split('=')
          params[key] = value
          params
        end
      end
    end

  end
end
