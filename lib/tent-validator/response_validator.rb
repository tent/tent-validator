module TentValidator
  class ResponseValidator

    Error = Class.new(StandardError)
    ValidatorNotFoundError = Class.new(Error)

    class << self
      attr_accessor :validators
    end

    def self.register(name)
      ResponseValidator.validators ||= {}
      ResponseValidator.validators[name.to_s] = self
    end

    def self.validate(name, options={}, &block)
      raise ValidatorNotFoundError.new(name) unless ResponseValidator.validators && validator = ResponseValidator.validators[name.to_s]
      response = yield
      validator.new.validate(response, options)
    end
  end
end
