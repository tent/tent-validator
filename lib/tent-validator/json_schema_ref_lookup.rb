module JSON
  class Schema
    class RefAttribute < Attribute
      def self.get_referenced_uri_and_schema(s, current_schema, validator)
        uri, schema = nil

        uri = URI.parse(s['$ref'])
        last_fragment = uri.fragment.split("/").last
        schema = JSON::Schema.new(TentSchemas[last_fragment], uri, validator)

        [uri, schema]
      end
    end
  end
end
