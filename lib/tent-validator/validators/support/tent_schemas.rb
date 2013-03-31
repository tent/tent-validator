require 'tent-schemas'

TentSchemas.schemas.each_pair do |name, schema|
  TentSchemas.inject_refs!(TentValidator::Schemas.register(name, schema))
end
