module TentValidator
  class JSONGenerator
    class << self
      attr_accessor :_generators
    end

    GeneratorNotFoundError = Class.new(StandardError)

    def self.generators
      JSONGenerator._generators ||= {}
    end

    def self.register(name)
      JSONGenerator.generators[name] = self
    end

    def self.generate(name, method)
      raise GeneratorNotFoundError.new(name) unless generator = JSONGenerator.generators[name]
      generator.new.send(method)
    end

    private

    def random_id
      SecureRandom.urlsafe_base64(16)
    end
  end
end

Dir[File.join(File.expand_path(File.dirname(__FILE__)), 'json_generator', '*.rb')].each do |file|
  require file
end
