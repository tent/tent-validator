module TentValidator
  class ValidationResultsStore
    def initialize(validation_id, remote_entity)
      @validation_id = validation_id
      @remote_entity = remote_entity
    end

    def start
      reset
      self.in_progress = true
    end

    def stop
      self.in_progress = false
    end

    def in_progress=(state)
      redis_client.set(progress_redis_key, Yajl::Encoder.encode(state))
    end

    def in_progress?
      Yajl::Parser.parse(redis_client.get(progress_redis_key).to_s)
    end

    def reset
      redis_client.del(results_redis_key)
      redis_client.del(progress_redis_key)
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

    def progress_redis_key
      @progress_key ||= "#{results_redis_key.sub(@validation_id, @remote_entity)}:running"
    end

    def append_results(results)
      redis_client.rpush(results_redis_key, Yajl::Encoder.encode(results.as_json))
    end

    def results(options={})
      redis_client.lrange(results_redis_key, 0, -1).to_a.map { |r| Yajl::Parser.parse(r) }
    end
  end
end
