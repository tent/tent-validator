require 'tent-client'

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

    def run
      instance_eval(&@block) if @block
      Results.new(@expectations.map(&:call))
    end

    def with_client(type, options, &block)
      client = if options[:server] == :remote
        TentClient.new(TentValidator.remote_server, TentValidator.remote_auth_details)
      else
        TentClient.new("", :faraday_adapter => TentValidator.local_adapter)
      end

      Context.new(env) do
        env[:client] = client
        env[:server] = options[:server] || :local

        instance_eval(&block)
      end
    end

    def expect_response(name, params = {}, &block)
      @expectations << proc do
        ResponseValidator.validate(name, params, &block)
      end
    end
  end
end
