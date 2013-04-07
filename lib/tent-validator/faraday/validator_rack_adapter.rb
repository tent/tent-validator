require 'tent-validator/faraday/validator_adapter'

module TentValidator

  class ValidatorRackFaradayAdapter < Faraday::Adapter::Rack
    include ValidatorFaradayAdapter

    def call(env)
      capture_request_body(env)
      super
    end
  end
  Faraday.register_middleware :adapter, :validator_rack => ValidatorRackFaradayAdapter

end
