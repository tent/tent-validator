module TentValidator

  class TentNetHttpFaradayAdapter < Faraday::Adapter::NetHttp
    def call(env)
      if Faraday::CompositeReadIO === env[:body]
        env[:request_body] = env[:body].read
        env[:body].rewind
      elsif env[:body]
        env[:request_body] = env[:body]
      end

      super
    end
  end
  Faraday.register_middleware :adapter, :tent_net_http => TentNetHttpFaradayAdapter

end
