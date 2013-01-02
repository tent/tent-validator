module TentValidator
  class Results < Array
    def initialize(results)
      @results = results
      super(@results)
    end

    def passed?
      @passed ||= !@results.any? { |r| !r.passed? }
    end

    def as_json(options = {})
      @results.map { |r| r.as_json(options) }
    end
  end
end
