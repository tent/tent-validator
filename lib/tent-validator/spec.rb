require 'tent-canonical-json'
require 'tent-validator/request_expectation'
require 'tent-validator/negative_request_expectation'

module TentValidator
  class Spec < ApiValidator::Spec

    require 'faraday_middleware'
    class LocalRequestMiddleware < Faraday::Middleware
      def call(env)
        env[:request_headers]['Validator-Request'] = 'true'
        @app.call(env)
      end
    end

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

      def uri_tempalte(name, options = {})
        meta = case options.delete(:server)
        when :local
          TentD::Utils::Hash.stringify_keys(options.delete(:user).meta_post.as_json)
        else
          TentValidator.remote_server_meta
        end

        servers = meta['content']['servers'].sort_by { |s| s['preference'] }
        server = if match_url = options.delete(:match)
          match_url = URI(match_url)
          servers.find { |s|
            _uri = URI(s['urls'][name.to_s].gsub(/{|}/, ''))
            _uri.host == match_url.host && _uri.port == match_url.port && _uri.scheme == match_url.scheme
          }
        else
          servers.first
        end

        server ? server['urls'][name.to_s] : nil
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
            :faraday_setup => proc { |faraday|
              faraday.use LocalRequestMiddleware
            },
            :server_meta => TentD::Utils::Hash.stringify_keys(user.meta_post.as_json)
          }

          if type == :app_auth
            TentClient.new(user.entity, {:credentials => TentD::Utils::Hash.symbolize_keys(user.server_credentials)}.merge(opts))
          else # no_auth
            TentClient.new(user.entity, opts)
          end
        end
      end

      def expect_discovery(user)
        expect_request(
          :method => :head,
          :url => %r{\A#{Regexp.escape(user.entity)}},
          :path => "/"
        )
        expect_request(
          :method => :get,
          :url => %r{\A#{Regexp.escape(user.entity)}},
          :path => "/posts/#{URI.encode_www_form_component(user.entity)}/#{user.meta_post.public_id}",
          :headers => {
            "Accept" => Regexp.new("\\A" + Regexp.escape(TentD::API::POST_CONTENT_MIME))
          }
        ).expect_response(:status => 200, :schema => :data) do
          expect_properties(:post => user.meta_post.as_json)
        end
      end

      def catch_faraday_exceptions(msg, &block)
        begin
          yield
        rescue Faraday::Error::ConnectionFailed, Faraday::Error::TimeoutError => e
          # Expose original exception
          raise SetupFailure.new("#{msg}: #{e.instance_eval { (@wrapped_exception || self).inspect }}", e.response)
        end
      end

      def auth_details_for_app_type(type, options={})
        credentials = case type
        when :app_auth
          # app authorization credentials
          TentValidator.remote_app_authorization_credentials
        when :app
          # app credentials
          TentValidator.remote_app_credentials
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

    Webhook = Struct.new(:id, :url)
    def generate_webhook
      id = TentD::Utils.random_id
      TentValidator.mutex.synchronize do
        TentValidator.webhooks[id] = { :response => [200, {}, []] }
      end
      Webhook.new(id, "http://localhost:#{TentValidator.local_server_port}/#{id}/webhooks")
    end

    def build_request_url(env)
      "http://#{env['HTTP_HOST']}#{env['PATH_INFO']}"
    end

    ##
    # options
    #   :url
    #   :method
    def manipulate_local_requests(user_id, options = {}, &block)
      TentValidator.mutex.synchronize do
        TentValidator.manipulate_requests[user_id] = proc do |env, app|
          request_url = build_request_url(env.merge('PATH_INFO' => env['ORIGINAL_PATH_INFO']))
          if (!options[:url] || options[:url] == request_url) && (!options[:method] || options[:method] == env['REQUEST_METHOD'])
            yield(env, app)
          else
            app.call(env)
          end
        end
      end
    end

    def watch_local_requests(should, user_id)
      TentValidator.mutex.synchronize do
        if should
          TentValidator.pending_local_requests.delete_if { true }
          TentValidator.watch_local_requests[user_id] = should
        else
          TentValidator.watch_local_requests.delete(user_id)
        end
      end
    end

    def expect_request(options = {}, &block)
      if options.delete(:negative_expectation)
        expectation = NegativeRequestExpectation.new(self, options, &block)
      else
        expectation = RequestExpectation.new(self, options, &block)
      end

      self.expectations << expectation
      expectation
    end

    def expect_async_request(options = {}, &block)
      if options.delete(:negative_expectation)
        expectation = NegativeRequestExpectation.new(self, options, &block)
      else
        expectation = RequestExpectation.new(self, options, &block)
      end

      TentValidator.mutex.synchronize do
        TentValidator.async_local_request_expectations << expectation
      end

      expectation
    end

  end
end
