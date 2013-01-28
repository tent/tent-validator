require 'tent-client'
require 'tentd/core_ext/hash/slice'

module TentValidator
  class ExampleGroup
    class Context
      attr_reader :env

      def initialize(env, &block)
        @env = env.dup
        instance_eval(&block) if block_given?
      end

      def method_missing(method_name, *args, &block)
        if @env.has_key?(method_name.to_sym) && args.empty?
          @env[method_name.to_sym]
        elsif @env[:example_group].respond_to?(method_name)
          _block = block ? proc { instance_eval(&block) } : nil
          @env[:example_group].send(method_name, *args, &_block)
        else
          super
        end
      end
    end

    class Results < TentValidator::Results
      attr_reader :context

      def initialize(results, context)
        @context = context
        super(results)
      end

      def as_json(options = {})
        {
          context.description => @results.map { |r| r.as_json(options) }
        }
      end
    end

    class Expectation
      attr_reader :context

      def initialize(context, name, options, &block)
        @context = context
        @name = name
        @options = options
        @block = block
        @after_hooks = []
      end

      def run
        result = ResponseValidator.validate(@name, @options, &@block)
        result.expectation = self
        run_after_hooks(result)
        result
      end

      def run_after_hooks(result)
        @after_hooks.each do |block|
          block.call(result)
        end
      end

      def after(&block)
        @after_hooks << block if block
      end
    end

    attr_reader :description, :env, :state, :dependent_example_groups

    def initialize(description="", options = {}, &block)
      @description, @block = description, block
      @pending = true unless @block
      @expectations = []
      @env = {
        :example_group => self
      }

      @dependent_example_groups = []

      if options[:depends_on]
        @dependent = true
        @state = options[:depends_on].state
        options[:depends_on].dependent_example_groups << self
      else
        @state = {}
      end
    end

    def dependent?
      !!@dependent
    end

    def pending?
      !!@pending
    end

    def set(key, value)
      @state[key.to_s] = value
    end

    def get(key)
      @state[key.to_s]
    end

    def reset
      @expectations = []
    end

    def run
      reset && instance_eval(&@block) if @block
      Results.new(@expectations.map(&:run), self)
    end

    def with_client(type, options, &block)
      client = if options[:server] == :remote
        TentClient.new(TentValidator.remote_server, auth_details_for_app_type(type, options).merge(
          :faraday_adapter => TentValidator.remote_adapter
        ))
      else
        TentClient.new("http://example.org", :faraday_adapter => TentValidator.local_adapter)
      end

      Context.new(env) do
        env[:client] = client
        env[:server] = options[:server] || :local

        instance_eval(&block)
      end
    end

    def expect_response(name, options = {}, &block)
      expectation = Expectation.new(self, name, options, &block)
      @expectations << expectation
      expectation
    end

    private

    def auth_details_for_app_type(type, options={})
      case type
      when :app
        TentValidator.remote_auth_details
      when :custom
        options.slice(:mac_key_id, :mac_algorithm, :mac_key)
      else
        Hash.new
      end
    end
  end
end
