require "tent-validator/version"
require "tentd"

module TentValidator
  autoload :Validation, 'tent-validator/validation'
  autoload :ExampleGroup, 'tent-validator/example_group'
  autoload :Results, 'tent-validator/results'
  autoload :CombinedResults, 'tent-validator/combined_results'
  autoload :ResponseValidator, 'tent-validator/response_validator'

  class << self
    attr_accessor :remote_server, :remote_auth_details
  end

  def self.tentd
    @tentd ||= TentD.new(:job_backend => 'sidekiq')
  end

  def self.local_adapter
    @local_adapter ||= [:tent_rack, tentd]
  end
end
