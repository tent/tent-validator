module TentValidator
  module Spec
    def self.run
      Dir[File.join(File.expand_path(File.dirname(__FILE__)), 'spec', '*.rb')].each { |f| require f }
      Validation.run
    end
  end
end
