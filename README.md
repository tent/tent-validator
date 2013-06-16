# TentValidator

Tent v0.3 protocol validator.

## Usage

### Integration testing any Tent server implementation

It's assumed you have redis and postgres running.

```bash
cd tent-validator
bundle
createdb tent-validator
createdb tent-validator-tentd && DATABASE_URL=postgres://localhost/tent-validator-tentd bundle exec rake db:migrate

echo "VALIDATOR_DATABASE_URL=postgres://localhost/tent-validator 
TENT_DATABASE_URL=postgres://localhost/tent-validator-tentd 
REDIS_URL=redis://127.0.0.1:6379/0 
REDIS_NAMESPACE=tent-validator " > .env
```

#### Commandline Runner

```ruby
require 'tent-validator'

# ... code to run your server implementation ...

server_url = "http://127.0.0.1:3000" # change to wherever the server is running

TentValidator.setup!(
  :remote_entity_uri => server_url,
  :tent_database_url => ENV['VALIDATOR_TENTD_DATABASE_URL'] # tent-validator uses tentd (defaults to `ENV['TENT_DATABASE_URL']`)
)

TentValidator::Runner::CLI.run
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
