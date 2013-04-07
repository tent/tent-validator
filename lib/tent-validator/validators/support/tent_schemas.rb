require 'tent-schemas'

TentSchemas.schemas.each_pair do |name, schema|
  ApiValidator::JsonSchemas.register(name, TentSchemas.inject_refs!(schema))
end
