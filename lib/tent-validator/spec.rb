Dir[File.join(File.expand_path(File.dirname(__FILE__)), 'spec', 'support', '*.rb')].each do |file|
  require file
end

%w( followings profile groups apps ).each do |validation_name|
  require "tent-validator/spec/#{validation_name}_validation"
end

module TentValidator
  module Spec
    def self.run(&block)
      return unless verify_authorization
      FollowingsValidation.run(&block)
      ProfileValidation.run(&block)
      GroupsValidation.run(&block)
      AppsValidation.run(&block)
    end

    def self.verify_authorization
      client = TentClient.new(TentValidator.remote_server, TentValidator.remote_auth_details)
      res = client.app.list
      res.success?
    end
  end
end
