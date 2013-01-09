require "tent-validator/version"
require "tentd"

module TentValidator
  autoload :Validation, 'tent-validator/validation'
  autoload :ExampleGroup, 'tent-validator/example_group'
  autoload :Results, 'tent-validator/results'
  autoload :ResponseValidator, 'tent-validator/response_validator'
  autoload :Spec, 'tent-validator/spec'
  autoload :App, 'tent-validator/app'

  class TentRackFaradayAdapter < Faraday::Adapter::Rack
    def call(env)
      env[:request_body] = env[:body].dup if env[:body]
      super
    end
  end
  Faraday.register_middleware :adapter, :tent_rack => TentRackFaradayAdapter

  class TentNetHttpFaradayAdapter < Faraday::Adapter::NetHttp
    def call(env)
      env[:request_body] = env[:body].dup if env[:body]
      super
    end
  end
  Faraday.register_middleware :adapter, :tent_net_http => TentNetHttpFaradayAdapter

  class << self
    attr_accessor :remote_server, :remote_auth_details
  end

  def self.tentd
    @tentd ||= TentD.new(:job_backend => 'sidekiq', :database => ENV['TENT_DATABASE_URL'])
  end

  def self.local_adapter
    @local_adapter ||= [:tent_rack, tentd]
  end

  def self.remote_adapter
    @remote_adapter ||= :tent_net_http
  end
end
