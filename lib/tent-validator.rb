require "tent-validator/version"
require "tent-validator/sidekiq"
require "tentd"
require "tent-validator/core_ext/hash"

module TentValidator
  autoload :Validation, 'tent-validator/validation'
  autoload :ExampleGroup, 'tent-validator/example_group'
  autoload :Results, 'tent-validator/results'
  autoload :ResponseValidator, 'tent-validator/response_validator'
  autoload :ParamValidator, 'tent-validator/param_validator'
  autoload :MergedParamValidator, 'tent-validator/param_validator/merged'
  autoload :LimitParamValidator, 'tent-validator/param_validator/limit'
  autoload :ExampleGroupRunner, 'tent-validator/example_group_runner'
  autoload :ValidationRunner, 'tent-validator/validation_runner'
  autoload :ValidationResultsStore, 'tent-validator/validation_results_store'
  autoload :JSONGenerator, 'tent-validator/json_generator'
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
    attr_accessor :remote_entity, :remote_server, :remote_auth_details
  end

  def self.tentd
    @tentd ||= TentD.new(:job_backend => 'sidekiq', :database => ENV['TENT_DATABASE_URL'])
  end

  def self.local_adapter(user)
    [:tent_rack, lambda { |env|
      env['tent.entity'] = user.entity
      match = env['PATH_INFO'] =~ %r{\A(/([^/]+)/tent)(.*)}
      env['PATH_INFO'] = $3.to_s
      env['SCRIPT_NAME'] = $1.to_s
      tentd.call(env)
    }]
  end

  def self.remote_adapter
    @remote_adapter ||= :tent_net_http
  end
end
