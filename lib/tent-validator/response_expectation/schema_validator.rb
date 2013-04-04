require 'json-pointer'

module TentValidator
  class ResponseExpectation

    class SchemaValidator < BaseValidator
      SchemaNotFoundError = Class.new(StandardError)

      attr_reader :root_path
      def initialize(expected, root_path = nil)
        @expected, @root_path = expected, root_path

        if Hash === expected
          schema = expected
        else
          unless schema = Schemas[expected]
            raise SchemaNotFoundError.new("Unable to locate schema: #{expected.inspect}")
          end
        end

        @schema = schema

        initialize_assertions(schema)
      end

      def validate(response)
        response_body = response.body.respond_to?(:to_hash) ? response.body.to_hash : response.body
        _failed_assertions = failed_assertions(response_body)
        _diff = diff(response_body, _failed_assertions)
        super.merge(
          :key => :response_body,
          :failed_assertions => _failed_assertions.map(&:to_hash),
          :diff => _diff,
          :valid => _diff.empty?
        )
      end

      def initialize_assertions(schema, parent_path = "")
        parent_path = root_path if root_path && parent_path == ""
        (schema["properties"] || {}).each_pair do |key, val|
          next unless val["required"] == true
          path = [parent_path, key].join("/")
          assertions << Assertion.new(path, nil, :type => val["type"])
          if val["type"] == "object"
            initialize_assertions(val, path)
          end
        end
      end

      def failed_assertions(actual)
        assertions.select do |assertion|
          pointer = JsonPointer.new(actual, assertion.path)
          !pointer.exists? || !assertion_valid?(assertion, pointer.value)
        end
      end

      def diff(actual, _failed_assertions)
        _diff = _failed_assertions.inject([]) do |memo, assertion|
          pointer = JsonPointer.new(actual, assertion.path)
          if !pointer.exists?
            assertion = assertion.to_hash
            actual_value = nil
            assertion[:op] = "add"
            assertion[:value] = value_for_schema_type(assertion[:type], actual_value)
            assertion[:message] = wrong_type_message(assertion[:type], schema_type(actual_value))
            memo << assertion
          end
          memo
        end

        _diff + schema_diff(@schema, actual)
      end

      def schema_diff(schema, actual, parent_path = "")
        properties = schema["properties"]

        return [] unless Hash === actual

        if root_path && parent_path == ""
          pointer = JsonPointer.new(actual, root_path)
          return [] unless pointer.exists?
          actual = pointer.value

          parent_path = root_path
        end

        actual.inject([]) do |memo, (key, val)|
          path = [parent_path, key].join("/")
          if property = properties[key.to_s]
            schema_property_diff(property, val, path) do |diff_item|
              memo << diff_item
            end
          else
            memo << { :op => "remove", :path => path }
          end
          memo
        end
      end

      def schema_property_diff(property, actual, path, &block)
        assertion = Assertion.new(path, nil, :type => property["type"], :format => property["format"])

        if !assertion_valid?(assertion, actual)
          yield({
            :op => "replace",
            :path => path,
            :value => value_for_schema_type(assertion.type, actual),
            :current_value => actual,
            :type => assertion.type,
            :message => wrong_type_message(assertion.type, schema_type(actual))
          })
        elsif (property["type"] == "object") && (Hash === property["properties"])
          schema_diff(property, actual, path).each { |d| yield(d) }
        elsif (property['type'] == 'array') && (Hash === property['items'])
          array_property = property['items']
          actual.each_with_index do |val, index|
            schema_property_diff(array_property, val, path + "/#{index}", &block)
          end
        end
      end

      def wrong_type_message(expected_type, actual_type)
        "expected type #{expected_type}, got #{actual_type}"
      end

      def assertion_valid?(assertion, actual)
        type = assertion.type
        case type
        when "array"
          Array === actual
        when "boolean"
          (TrueClass === actual) || (FalseClass === actual)
        when "integer"
          Fixnum === actual
        when "number"
          Numeric === actual
        when "null"
          NilClass === actual
        when "object"
          Hash === actual
        when "string"
          String === actual
        else
          super
        end
      end

      def schema_type(value)
        case value
        when Array
          "array"
        when TrueClass, FalseClass
          "boolean"
        when Fixnum
          "integer"
        when Numeric
          "number"
        when NilClass
          "null"
        when Hash
          "object"
        when String
          "string"
        else
          "unknown"
        end
      end

      def value_for_schema_type(type, value)
        klass = class_for_schema_type(type)
        if klass == Array
          value.respond_to?(:to_a) ? value.to_a : Array.new
        elsif klass == [TrueClass, FalseClass]
          !!value
        elsif klass == Fixnum
          value.respond_to?(:to_i) ? value.to_i : 0
        elsif klass == Numeric
          value.respond_to?(:to_f) ? value.to_f : 0.0
        elsif klass == Hash
          value.respond_to?(:to_hash) ? value.to_hash : Hash.new
        elsif klass == String
          value.respond_to?(:to_s) ? value.to_s : ""
        else
          nil
        end
      end

      def class_for_schema_type(type)
        case type
        when "array"
          Array
        when "boolean"
          [TrueClass, FalseClass]
        when "integer"
          Fixnum
        when "number"
          Numeric
        when "null"
          NilClass
        when "object"
          Hash
        when "string"
          String
        end
      end
    end

  end
end
