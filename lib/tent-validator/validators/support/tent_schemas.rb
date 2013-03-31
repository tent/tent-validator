require 'tent-schemas'

TentSchemas.schemas.each_pair do |name, schema|
  TentValidator::Schemas.register(name, schema)
end
