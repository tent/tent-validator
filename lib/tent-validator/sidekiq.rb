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

    def perform(msg)
      TentValidator.remote_server = msg['remote_server']
      TentValidator.remote_auth_details = msg['remote_auth_details']

      @validation_id = msg['validation_id']

      Spec.run do |results|
        example_group_completed(results)
      end
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
