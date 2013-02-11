module TentValidator
  class ParamValidator
    class << self
      attr_accessor :_registered_validators
      attr_reader :registered_name
    end

    def self.registered_validators
      ParamValidator._registered_validators ||= {}
    end

    def self.register(name)
      @registered_name = name
      registered_validators[name] = self
    end

    def self.find(name)
      registered_validators[name]
    end

    def self.with(*names, &block)
      options = names.last.kind_of?(Hash) ? names.pop : {}
      merge_hooks[names.size == 1 ? names.first : names.sort] = [block, options]
    end

    def self.merge_hooks
      @merge_hooks ||= {}
    end

    def initialize(options)
      @options = options
    end

    def merge(*others)
      MergedParamValidator.new(self, *others, @options)
    end

    def merge_hooks_for(*names)
      names.inject([]) do |memo, name|
        hook, options = self.class.merge_hooks[name]

        unless hook
          name_combinations(names).find { |combination|
            hook, options = self.class.merge_hooks[combination.sort]
          }
        end

        memo << hook if hook && (options[:not].nil? || !(names + [self.send(:name)]).any? { |n| Array(options[:not]).include?(n) })
        memo
      end
    end

    def name_combinations(names)
      names.size.times.inject([]) do |memo, i|
        memo + names.combination(i + 1).to_a
      end
    end

    def name
      self.class.registered_name
    end

    def resources
      @options[:resources]
    end

    def response_expectation_options
      @response_expectation_options ||= generate_response_expectation_options
    end

    def generate_response_expectation_options
      Hash.new
    end

    def client_params
      @client_params ||= generate_client_params
    end

    def generate_client_params
      Hash.new
    end
  end
end
