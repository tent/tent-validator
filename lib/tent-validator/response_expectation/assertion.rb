module TentValidator
  class ResponseExpectation

    class Assertion
      attr_reader :value, :path, :type, :format
      def initialize(path, value, options = {})
        @path, @value, @type, @format = path, value, options.delete(:type), options.delete(:format)
      end

      def to_hash(options = {})
        _h = { :op => "test", :path => path, :value => stringified_value }
        _h.delete(:value) if type && value.nil?
        _h[:type] = "regexp" if Regexp === value
        _h[:type] = type if type
        _h[:format] = format if format
        _h
      end

      def stringified_value
        if Regexp === value
          regex = value.to_s.
            sub(%r|\(\?-mix:(.*)\)|) { $1 }.
            gsub("\\A", "^").
            gsub("\\Z", "$")
          "/#{regex}/"
        else
          value
        end
      end
    end

  end
end
