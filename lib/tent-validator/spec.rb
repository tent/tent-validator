require 'tent-canonical-json'
require 'tent-validator/request_expectation'

module TentValidator
  class Spec < ApiValidator::Spec

    module SharedClassAndInstanceMethods
      def parse_params(query_string)
        query_string.to_s.sub(/\A\?/, '').split('&').inject({}) do |params, param|
          key,val = param.split('=')
          val = URI.decode_www_form_component(val)

          # Faraday allows specifying multiple params of the same name by assigning the key with an array of values
          if params.has_key?(key)
            if !params[key].kind_of?(Array)
              params[key] = [params[key]]
            end

            params[key] << val
          else
            params[key] = val
          end

          params
        end
      end

      def clients(type, options = {})
        server = options.delete(:server) || :remote
        if server == :remote
          TentClient.new(TentValidator.remote_entity_uri, auth_details_for_app_type(type, options).merge(
            :faraday_adapter => TentValidator.remote_adapter,
            :server_meta => TentValidator.remote_server_meta
          ))
        else
          user = options[:user]
          opts = {
            :faraday_adapter => TentValidator.remote_adapter,
            :server_meta => TentD::Utils::Hash.stringify_keys(user.meta_post.as_json)
          }

          if type == :app
            TentClient.new(user.entity, TentD::Utils::Hash.symbolize_keys(user.server_credentials).merge(opts))
          else # no_auth
            TentClient.new(user.entity, opts)
          end
        end
      end

      def auth_details_for_app_type(type, options={})
        credentials = case type
        when :app
          TentValidator.remote_auth_details
        when :custom
          {
            :id => options.delete(:id),
            :hawk_key => options.delete(:hawk_key),
            :hawk_algorithm => options.delete(:hawk_algorithm)
          }
        end

        credentials ? { :credentials => credentials } : Hash.new
      end

      def generate_version_signature(post)
        canonical_post_json = TentCanonicalJson.encode(post)
        hex_digest(canonical_post_json)
      end

      def hex_digest(input)
        TentD::Utils.hex_digest(input)
      end

      def invalid_value(type, format = nil)
        case type
        when "array"
          Hash.new
        when "boolean"
          "false"
        when "number", "integer"
          "123"
        when "null"
          true
        when "object"
          ["My parent should be an object!"]
        when "string"
          if format
            case format
            when 'uri'
              "I'm not a uri!"
            end
          else
            421
          end
        end
      end

      def valid_value(type, format = nil)
        case type
        when "array"
          []
        when "boolean"
          true
        when "number", "integer"
          123
        when "null"
          nil
        when "object"
          Hash.new
        when "string"
          if format
            case format
            when 'uri'
              "https://example.com"
            end
          else
            ""
          end
        end
      end
    end

    class << self
      include SharedClassAndInstanceMethods
    end
    include SharedClassAndInstanceMethods

    def self.property_absent
      ApiValidator::ResponseExpectation::PropertyAbsent.new
    end

    def watch_local_requests(should, user_id)
      if should
        TentValidator.watch_local_requests[user_id] = should
      else
        TentValidator.watch_local_requests.delete(user_id)
      end
    end

    def expect_request(options = {}, &block)
      expectation = RequestExpectation.new(self, options, &block)
      self.expectations << expectation
      expectation
    end

    def expect_async_request(options = {}, &block)
      expectation = RequestExpectation.new(self, options, &block)

      TentValidator.mutex.synchronize do
        TentValidator.async_local_request_expectations << expectation
      end

      expectation
    end

  end
end
