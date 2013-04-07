module TentValidator

  module ValidatorFaradayAdapter
    def capture_request_body(env)
      if Faraday::CompositeReadIO === env[:body]
        env[:request_body] = env[:body].read
        env[:body].rewind
      elsif env[:body]
        env[:request_body] = env[:body]
      end
      env
    end
  end

end
