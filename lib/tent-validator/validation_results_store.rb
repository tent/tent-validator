module TentValidator
  class ValidationResultsStore
    def initialize(validation_id)
      @validation_id = validation_id
    end

    def redis_client
      @redis_client ||= Redis.new(:url => ENV['REDIS_URL'])
    end

    def redis_namespace
      @redis_namespace ||= ENV['REDIS_NAMESPACE'].to_s
    end

    def wrap_redis_key(key)
      "#{redis_namespace}:#{key}"
    end

    def results_redis_key
      @results_key ||= wrap_redis_key("#{@validation_id}:results")
    end

    def append_results(results)
      redis_client.rpush(results_redis_key, Yajl::Encoder.encode(results.as_json))
    end

    def results(options={})
      redis_client.lrange(results_redis_key, 0, -1).to_a.map { |r| Yajl::Parser.parse(r) }
    end
  end
end
