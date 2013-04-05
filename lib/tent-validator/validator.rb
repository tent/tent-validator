require 'tent-canonical-json'

module TentValidator
  class Validator
    require 'tent-validator/validator/results'

    module SharedClassAndInstanceMethods
      def validator?
        true
      end

      def shared_examples
        @shared_examples ||= self.respond_to?(:superclass) && self.superclass.respond_to?(:validator?) && self.superclass.validator? ? self.superclass.shared_examples : {}
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
      validations.inject(Results.new(Validator.new(''), [])) do |memo, validation|
        results = validation.run
        memo.merge!(results)
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
        TentClient.new(TentValidator.remote_entity_uri, auth_details_for_app_type(type, options).merge(
          :faraday_adapter => TentValidator.remote_adapter,
          :server_meta => TentValidator.remote_server_meta
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

    def cache
      @cache ||= Hash.new
    end

    def get(path)
      if Symbol === path
        path = "/#{path}"
      end

      pointer = JsonPointer.new(cache, path, :symbolize_keys => true)
      unless pointer.exists?
        return parent ? parent.get(path) : nil
      end
      val = pointer.value
      Proc === val ? val.call : val
    end

    def set(path, val=nil, &block)
      if Symbol === path
        path = "/#{path}"
      end

      pointer = JsonPointer.new(cache, path, :symbolize_keys => true)
      pointer.value = block_given? ? block : val
      val
    end

    def generate_version_signature(post)
      canonical_post_json = TentCanonicalJson.encode(post)
      Digest::SHA512.new.update(canonical_post_json).to_s[0...64]
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
