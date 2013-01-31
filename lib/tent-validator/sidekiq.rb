require "sidekiq"
require "redis"
require "yajl"
require "tent-validator"

module TentValidator
  sidekiq_config = lambda { |config|
    config.redis = { url: ENV['REDIS_URL'], :namespace => ENV['REDIS_NAMESPACE'] }
  }
  Sidekiq.configure_server(&sidekiq_config)
  Sidekiq.configure_client(&sidekiq_config)

  class ValidationWorker
    include Sidekiq::Worker

    ValidationInProgressError = Class.new(StandardError)

    def perform(msg)
      TentValidator.remote_entity = msg['remote_entity']
      TentValidator.remote_server = msg['remote_server']
      TentValidator.remote_auth_details = msg['remote_auth_details'].inject({}) { |memo, (k,v)|
        memo[k.to_sym] = v
        memo
      }

      @validation_id = msg['validation_id']
      raise ValidationInProgressError if results_store.in_progress?

      results_store.start
      Spec.run do |results|
        example_group_completed(results)
      end
      results_store.stop
    rescue => e
      results_store.stop unless e.kind_of?(ValidationInProgressError)
      raise
    end

    private

    def results_store
      @results_store ||= ValidationResultsStore.new(@validation_id)
    end

    def example_group_completed(results)
      results_store.append_results(results)
    end
  end
end
