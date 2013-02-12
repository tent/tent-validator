module TentValidator
  class SinceIdParamValidator < ParamValidator
    register :since_id

    def generate_response_expectation_options
      {
        :body_begins_with => resources[0..-2],
        :body_excludes => [resources.last]
      }
    end

    def generate_client_params
      {
        :since_id => resources.last['id']
      }
    end
  end
end
