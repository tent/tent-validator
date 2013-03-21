module TentValidator
  class ResponseExpectation

    class Assertion
      attr_reader :value, :path
      def initialize(path, value)
        @path, @value = path, value

        @stringified_value = if Regexp === value
          regex = value.to_s.
            sub(%r|\(\?-mix:(.*)\)|) { $1 }.
            gsub("\\A", "^").
            gsub("\\Z", "$")
          "/#{regex}/"
        else
          value
        end
      end

      def to_hash(options = {})
        _h = { :op => "test", :path => path, :value => @stringified_value }
        _h[:type] = "regexp" if Regexp === @value
        _h
      end
    end

  end
end
