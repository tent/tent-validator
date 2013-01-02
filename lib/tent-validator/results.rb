module TentValidator
  class Results

    def initialize(results_array=[])
      @results_array = results_array
    end

    def passed?
      @passed ||= !@results_array.any? { |result| result != true }
    end

  end
end
