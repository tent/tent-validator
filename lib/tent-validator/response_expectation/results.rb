module TentValidator
  class ResponseExpectation

    class Results
      attr_reader :response, :results
      def initialize(response, results)
        @response, @results = response, results
      end

      def as_json(options = {})
        res = results.inject(Hash.new) do |memo, result|
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

      def deep_merge!(hash, *others)
        others.each do |other|
          other.each_pair do |key, val|
            if hash.has_key?(key)
              next if hash[key] == val
              case val
              when Hash
                deep_merge!(hash[key], val)
              when Array
                hash[key].concat(val)
              when FalseClass
                # false always wins
                hash[key] = val
              end
            else
              hash[key] = val
            end
          end
        end
      end

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
