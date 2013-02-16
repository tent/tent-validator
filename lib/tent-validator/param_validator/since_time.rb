module TentValidator
  class SinceTimeParamValidator < ParamValidator
    register :since_time

    with :limit, :not => :before_time do |instance|
      instance.response_expectation_options[:body_begins_with] = instance.response_expectation_options[:body_begins_with].reverse.slice(0, instance.client_params[:limit]).reverse
    end

    def generate_response_expectation_options
      {
        :body_begins_with => resources[0..-2],
        :body_excludes => [resources.last]
      }
    end

    def generate_client_params
      {
        :since_time => resources.last['received_at']
      }
    end
  end
end
