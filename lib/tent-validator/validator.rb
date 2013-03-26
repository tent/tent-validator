module TentValidator
  class Validator
    require 'tent-validator/validator/results'

    module SharedClassAndInstanceMethods
      def shared_examples
        @shared_examples ||= {}
      end

      def shared_example(name, &block)
        self.shared_examples[name] = block
      end

      def validations
        @validations ||= []
      end

      def describe(name, options = {}, &block)
        validation = self.new(name, options.merge(:parent => self), &block)
        self.validations << validation
        validation
      end
      alias context describe
    end

    class << self
      include SharedClassAndInstanceMethods
    end
    include SharedClassAndInstanceMethods

    def self.run
      validations.inject(nil) do |memo, validation|
        results = validation.run
        if memo
          memo.merge!(results)
        else
          results
        end
      end
    end

    attr_reader :parent, :name, :pending
    def initialize(name, options = {}, &block)
      @parent = options.delete(:parent)
      @parent = nil if @parent == self.class
      @name = name

      initialize_before_hooks(options.delete(:before))

      if block_given?
        instance_eval(&block)
      else
        @pending = true
      end
    end

    def initialize_before_hooks(hooks)
      Array(hooks).each do |method_name_or_block|
        if method_name_or_block.respond_to?(:call)
          self.before_hooks << method_name_or_block
        elsif respond_to?(method_name_or_block)
          self.before_hooks << method(method_name_or_block)
        end
      end
    end

    def before_hooks
      @before_hooks ||= []
    end

    def new(*args, &block)
      self.class.new(*args, &block)
    end

    def find_shared_example(name)
      ref = self
      begin
        if block = ref.shared_examples[name]
          return block
        end
      end while ref = ref.parent
      self.class.shared_examples[name]
    end

    BehaviourNotFoundError = Class.new(StandardError)
    def behaves_as(name)
      block = find_shared_example(name)
      raise BehaviourNotFoundError.new("Behaviour #{name.inspect} could not be found") unless block
      instance_eval(&block)
    end

    def clients(type, options = {})
      server = options.delete(:server) || :remote
      if server == :remote
        TentClient.new(TentValidator.remote_server_urls, auth_details_for_app_type(type, options).merge(
          :faraday_adapter => TentValidator.remote_adapter
        ))
      else
      end
    end

    def expectations
      @expectations ||= []
    end

    def expect_response(options = {}, &block)
      expectation = ResponseExpectation.new(self, options, &block)
      self.expectations << expectation
      expectation
    end

    def run
      before_hooks.each do |hook|
        if hook.respond_to?(:receiver) && hook.receiver == self
          # It's a method
          hook.call
        else
          # It's a block
          instance_eval(&hook)
        end
      end

      results = self.expectations.inject([]) do |memo, expectation|
        memo << expectation.run
      end

      self.validations.inject(Results.new(self, results)) do |memo, validation|
        memo.merge!(validation.run)
      end
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
