module TentValidator
  class NegativeRequestExpectation < RequestExpectation

    def negative?
      true
    end

    def validate(request)
      invert_results(super)
    end

    def validate_response(env, response)
      invert_results(super)
    end

    private

    def invert_results(results)
      results.each do |result|
        result[:valid] = !result[:valid]
        result[:failed_assertions] = result[:assertions] - result[:failed_assertions]
        result[:diff] = []
      end

      results
    end

  end
end
