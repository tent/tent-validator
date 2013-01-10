module TentValidator
  module Spec
    def self.run(&block)
      Dir[File.join(File.expand_path(File.dirname(__FILE__)), 'spec', '*.rb')].each { |f| require f }
      Validation.run(&block)
    end
  end
end
