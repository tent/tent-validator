module TentValidator
  class BeforeIdParamValidator < ParamValidator
    register :before_id

    with :limit do |instance|
      instance.response_expectation_options[:body_begins_with] = instance.response_expectation_options[:body_begins_with].slice(0, instance.client_params[:limit])
    end

    def generate_response_expectation_options
      {
        :body_begins_with => resources[1..-1],
        :body_excludes => [resources.first]
      }
    end

    def generate_client_params
      {
        :before_id => resources.first['id']
      }
    end
  end
end
