module TentValidator
  class LimitParamValidator < ParamValidator
    register :limit

    def generate_response_expectation_options
      {
        :size => client_params[:limit]
      }
    end

    def generate_client_params
      {
        :limit => [rand(resources.size + 1), 1].max
      }
    end
  end
end
