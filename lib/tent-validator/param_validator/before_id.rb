module TentValidator
  class BeforeIdParamValidator < ParamValidator
    register :before_id

    with :limit, :not => :since_id do |instance|
      instance.response_expectation_options[:body_begins_with] = instance.response_expectation_options[:body_begins_with].slice(0, instance.client_params[:limit])
    end

    with :since_id, :not => :limit do |instance|
      instance.response_expectation_options[:body_begins_with] = instance.resources[1..-2]
      instance.response_expectation_options[:body_excludes] = [instance.resources.first, instance.resources.last]
    end

    with :since_id, :limit do |instance|
      instance.response_expectation_options[:body_begins_with] = instance.resources[1..-2].reverse.slice(0, instance.client_params[:limit]).reverse
      instance.response_expectation_options[:body_excludes] = [instance.resources.first, instance.resources.last]
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
