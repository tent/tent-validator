module TentValidator
  class MergedParamValidator < ParamValidator
    def initialize(*args)
      options = args.pop
      super(options)
      @validators = args

      @validators.each do |validator|
        hooks = validator.merge_hooks_for(*@validators.map(&:name))
        hooks.each { |block| block.call(self) }
      end
    end

    def generate_response_expectation_options
      @validators.inject({}) do |memo, validator|
        memo.deep_merge(validator.response_expectation_options)
      end
    end

    def generate_client_params
      @validators.inject({}) do |memo, validator|
        memo.deep_merge(validator.client_params)
      end
    end
  end
end
