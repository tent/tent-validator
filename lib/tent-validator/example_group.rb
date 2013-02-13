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

    class ParamExpectation
      def initialize(context, param_names, param_options)
        @context = context
        @param_names = param_names
        @param_options = param_options
      end

      def expect_response(name, options = {}, &block)
        param_name_combinations.each do |param_names|
          validator = param_validator(param_names.first).merge(*param_names[1..-1].map { |param_name|
            param_validator(param_name)
          })
          opts = validator.response_expectation_options.deep_merge(:client_params => validator.client_params).deep_merge(options)
          @context.expect_response(name, opts, &block)
        end
      end

      private

      def param_name_combinations
        # all combinations of param names
        @param_names.size.times.inject([]) do |memo, i|
          memo + @param_names.combination(i + 1).to_a
        end
      end

      def param_validator(param_name)
        ParamValidator.find(param_name).new(@param_options)
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

    def default_state
      @default_state ||= {
        :remote_entity => TentValidator.remote_entity
      }
    end

    def set(key, value)
      @state[key.to_s] = value
    end

    def get(key)
      @state[key.to_s] || default_state[key.to_sym]
    end

    def reset
      @expectations = []
    end

    def run
      reset && instance_eval(&@block) if @block
      Results.new(@expectations.map(&:run), self)
    end

    UserNotFoundError = Class.new(StandardError)
    def clients(type, options = {})
      if options[:server] == :remote
        TentClient.new(TentValidator.remote_server, auth_details_for_app_type(type, options).merge(
          :faraday_adapter => TentValidator.remote_adapter
        ))
      else
        user = TentD::Model::User.current = TentD::Model::User.first(:id => options[:user])
        raise UserNotFoundError.new("Expected :user => id option to be a valid user id") unless user
        TentClient.new(user.entity, user.app_authorization.auth_details.merge(:faraday_adapter => TentValidator.local_adapter(user)))
      end
    end

    def expect_response(name, options = {}, &block)
      name, options = [:void, name] if name.kind_of?(Hash)
      expectation = Expectation.new(self, name, options, &block)
      @expectations << expectation
      expectation
    end

    def validate_params(*args)
      options = args.last.kind_of?(Hash) ? args.pop : Hash.new
      ParamExpectation.new(self, args, options)
    end

    def create_resource(type, client_options, *args)
      ResourceFactory.create_resource(self, client_options, type, *args)
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
