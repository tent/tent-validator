# TentValidator

Tent v0.3 protocol validator.

## Usage

### Integration testing your Ruby Tent server implementation.

Add this line to your application's Gemfile:

    gem 'tent-validator'

And then execute:

    $ bundle


```ruby
require 'tent-validator'

class YourTentServer
  # ...

  def call(rack_env)
    # ...
  end

  # ...
end

TentValidator.remote_server = YourTentServer.new
TentValidator.run!
```

### Integration testing any Tent server implementation

It's assumed you have redis and postgres running, and a JavaScript runtime available (e.g. nodejs).

```bash
cd tent-validator
bundle
createdb tent-validator
createdb tent-validator-tentd && DATABASE_URL=postgres://localhost/tent-validator-tentd bundle exec rake tentd:db:migrate

echo "VALIDATOR_DATABASE_URL=postgres://localhost/tent-validator 
TENT_DATABASE_URL=postgres://localhost/tent-validator-tentd 
VALIDATOR_NOTIFICATION_URL=http://localhost:9292/webhooks 
COOKIE_SECRET=$(openssl rand -hex 16 | tr -d '\r\n') 
REDIS_URL=redis://127.0.0.1:6379/0 
REDIS_NAMESPACE=tent-validator 
VALIDATOR_HOST=http://localhost:9292" >> .env
gem install foreman
foreman run bundle exec puma -p 3000
```

```bash
open http://localhost:3000
```

Enter your entity URI when propted and authorize with your Tent server.

**WARNING: This app will create lots of posts (many of them public) and not delete all of them. For best results wipe the database for your entity's server between validation runs and don't use an entity with any followers.**

The app will then run validations against your server and display the results.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
