module TentValidator
  class RequestExpectation

    Response = Struct.new(:status, :headers, :body)
    Request = Struct.new(:headers, :body, :url, :path, :params, :method)

    class Results < ApiValidator::ResponseExpectation::Results
      attr_reader :request, :response, :results
      def initialize(request, response, results)
        @request, @response, @results = request, response, results
      end

      def as_json(options = {})
        res = results.inject(Hash.new) do |memo, result|
          result = result.dup
          deep_merge!((memo[result.delete(:key)] ||= Hash.new), result)
          memo
        end

        merge_diffs!(res)

        {
          :expected => res,
          :actual => {
            :request_headers => request.headers || {},
            :request_body => request.body,
            :request_path => request.path,
            :request_params => request.params || {},
            :request_url => request.url,
            :request_method => request.method.to_s.upcase,

            :response_headers => response.headers || {},
            :response_body => response.body,
            :response_status => response.status
          }
        }
      end
    end

    class HeaderExpectation < ApiValidator::Header
      def validate(request)
        compiled_assertions = compile_assertions(request)
        request_headers = request.headers
        _failed_assertions = failed_assertions(compiled_assertions, request_headers)
        {
          :assertions => compiled_assertions.map(&:to_hash),
          :key => :request_headers,
          :failed_assertions => _failed_assertions.map(&:to_hash),
          :diff => diff(request_headers, _failed_assertions).map(&:to_hash),
          :valid => _failed_assertions.empty?
        }
      end
    end

    class MethodExpectation < ApiValidator::Status
      def validate(request)
        request_method = request.method.to_s.upcase
        _failed_assertions = failed_assertions(request_method)
        {
          :assertions => assertions.map(&:to_hash),
          :key => :request_method,
          :failed_assertions => _failed_assertions.map(&:to_hash),
          :diff => diff(request_method, _failed_assertions),
          :valid => _failed_assertions.empty?
        }
      end
    end

    class PathExpectation < MethodExpectation
      def validate(request)
        request_path = request.path
        _failed_assertions = failed_assertions(request_path)
        {
          :assertions => assertions.map(&:to_hash),
          :key => :request_path,
          :failed_assertions => _failed_assertions.map(&:to_hash),
          :diff => diff(request_path, _failed_assertions),
          :valid => _failed_assertions.empty?
        }
      end
    end

    class ParamExpectation < HeaderExpectation
      def validate(request)
        request_params = request.params
        _failed_assertions = failed_assertions(assertions, request_params)
        {
          :assertions => assertions.map(&:to_hash),
          :key => :request_params,
          :failed_assertions => _failed_assertions.map(&:to_hash),
          :diff => diff(request_params, _failed_assertions).map(&:to_hash),
          :valid => _failed_assertions.empty?
        }
      end
    end

    class JsonExpectation < ApiValidator::Json
      def validate(request)
        request_body = begin
                         Yajl::Parser.parse(request.body)
                       rescue Yajl::ParseError
                         Hash.new
                       end
        _failed_assertions = failed_assertions(request_body)
        {
          :assertions => assertions.map(&:to_hash),
          :key => :request_body,
          :failed_assertions => _failed_assertions.map(&:to_hash),
          :diff => diff(request_body, _failed_assertions),
          :valid => _failed_assertions.empty?
        }
      end
    end

    attr_accessor :request, :response
    def initialize(validator, options, &block)
      @validator = validator
      initialize_headers(options.delete(:headers))
      initialize_method(options.delete(:method))
      initialize_path(options.delete(:path))
      initialize_params(options.delete(:params))
      initialize_body(options.delete(:body))
    end

    def header_expectations
      @header_expectations ||= []
    end

    def method_expectations
      @method_expectations ||= []
    end

    def path_expectations
      @path_expectations ||= []
    end

    def param_expectations
      @param_expectations ||= []
    end

    def json_expectations
      @json_expectations ||= []
    end

    def expectations
      header_expectations + method_expectations + path_expectations + param_expectations + json_expectations
    end

    def initialize_headers(expected_headers)
      return unless expected_headers
      header_expectations << HeaderExpectation.new(expected_headers)
    end

    def initialize_method(expected_method)
      return unless expected_method
      method_expectations << MethodExpectation.new(expected_method.to_s.upcase)
    end

    def initialize_path(expected_path)
      return unless expected_path
      path_expectations << PathExpectation.new(expected_path)
    end

    def initialize_params(expected_params)
      return unless expected_params
      param_expectations << ParamExpectation.new(expected_params)
    end

    def initialize_body(expected_body)
      return unless expected_body
      json_expectations << JsonExpectation.new(expected_body)
    end

    def run
      env, response = nil
      TentValidator.mutex.synchronize do
        env, response = Array(TentValidator.pending_local_requests.shift)
      end

      request = Request.new
      request.headers = parse_headers(env)
      request.url = parse_url(env)
      request.path = env ? env['PATH_INFO'] : nil
      request.params = parse_params(env)
      request.method = env ? env['REQUEST_METHOD'] : nil
      request.body = env ? env['REQUEST_BODY'] : nil

      response = Response.new(*response)
      response.headers ||= Hash.new

      expectations = validate(request)
      Results.new(request, response, expectations)
    end

    def validate(request)
      expectations.map { |expectation| expectation.validate(request) }
    end

    private

    def parse_headers(env)
      return Hash.new unless env
      headers = env.inject(Hash.new) do |headers, (k,v)|
        next headers unless k =~ /\AHTTP_/
        headers[k.sub(/\AHTTP_/, '')] = v
        headers
      end
      headers.merge(TentD::Utils::Hash.slice(env, 'CONTENT_TYPE'))
      %w[ VERSION USER_AGENT CONNECTION HOST ].each { |k| headers.delete(k) }
      headers.inject(Hash.new) do |headers, (key, val)|
        key = key.downcase.split('_').map { |part| part.sub(/\A([a-z])/) { $1.upcase } }.join('-')
        headers[key] = val
        headers
      end
    end

    def parse_url(env)
      return unless env
      url = "#{env['rack.url_scheme']}://#{env['HTTP_HOST']}#{env['REQUEST_PATH']}"
      url << "?#{env['QUERY_STRING']}" unless env['QUERY_STRING'] == ""
      url
    end

    def parse_params(env)
      return Hash.new unless env
      env['params'] || Hash.new
    end

  end
end