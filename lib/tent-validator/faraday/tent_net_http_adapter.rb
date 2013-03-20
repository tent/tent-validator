module TentValidator

  class TentNetHttpFaradayAdapter < Faraday::Adapter::NetHttp
    def call(env)
      env[:request_body] = env[:body].dup if env[:body]
      super
    end
  end
  Faraday.register_middleware :adapter, :tent_net_http => TentNetHttpFaradayAdapter

end
