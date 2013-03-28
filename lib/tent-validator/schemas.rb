module TentValidator
  class Schemas
    def self.register(schema_name, schema)
      schemas[schema_name.to_s] = schema
    end
    class << self
      alias []= register
    end

    def self.schemas
      @schemas ||= {}
    end

    def self.[](schema_name)
      schemas[schema_name.to_s]
    end
  end
end
