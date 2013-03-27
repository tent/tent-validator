require 'tent-validator/version'
require 'tent-validator/core_ext/hash/slice'
require 'faraday'
require 'tent-client'

module TentValidator

  require 'tent-validator/schemas'
  require 'tent-validator/validator'
  require 'tent-validator/response_expectation'

  require 'tent-validator/runner'

  require 'tent-validator/faraday/tent_rack_adapter'
  require 'tent-validator/faraday/tent_net_http_adapter'

  class << self
    attr_writer :remote_auth_details
    attr_accessor :remote_server_meta, :remote_entity_uri
  end

  def self.setup!(options = {})
    require 'tentd'
    TentD.setup!(:database_url => options[:tent_database_url] || ENV['TENT_DATABASE_URL'])

    [:remote_entity_uri, :remote_auth_details, :remote_server_meta].each do |key|
      if options.has_key?(key)
        self.send("#{key}=", options.delete(key))
      end
    end
  end

  def self.remote_auth_details
    @remote_auth_details || Hash.new
  end

  def self.remote_adapter
    @remote_adapter ||= :tent_net_http
  end

  def self.validators
    @validators ||= []
  end

end
