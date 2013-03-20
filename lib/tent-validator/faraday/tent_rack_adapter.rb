module TentValidator

  class TentRackFaradayAdapter < Faraday::Adapter::Rack
    def call(env)
      env[:request_body] = env[:body].dup if env[:body]
      super
    end
  end
  Faraday.register_middleware :adapter, :tent_rack => TentRackFaradayAdapter

end
