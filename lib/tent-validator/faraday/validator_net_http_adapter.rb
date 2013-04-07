require 'tent-validator/faraday/validator_adapter'

module TentValidator

  class ValidatorNetHttpFaradayAdapter < Faraday::Adapter::NetHttp
    include ValidatorFaradayAdapter

    def call(env)
      capture_request_body(env)
      super
    end
  end
  Faraday.register_middleware :adapter, :validator_net_http => ValidatorNetHttpFaradayAdapter

end
