Dir[File.join(File.expand_path(File.dirname(__FILE__)), 'spec', 'support', '*.rb')].each do |file|
  require file
end

%w( profile groups apps ).each do |validation_name|
  require "tent-validator/spec/#{validation_name}_validation"
end

module TentValidator
  module Spec
    def self.run(&block)
      ProfileValidation.run(&block)
      GroupsValidation.run(&block)
      AppsValidation.run(&block)
    end
  end
end
