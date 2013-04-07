# TentValidator

Tent v0.3 protocol validator.

## Usage

### Integration testing any Tent server implementation

It's assumed you have redis and postgres running.

```bash
cd tent-validator
bundle
createdb tent-validator
createdb tent-validator-tentd && DATABASE_URL=postgres://localhost/tent-validator-tentd bundle exec rake tentd:db:migrate

echo "VALIDATOR_DATABASE_URL=postgres://localhost/tent-validator 
TENT_DATABASE_URL=postgres://localhost/tent-validator-tentd 
REDIS_URL=redis://127.0.0.1:6379/0 
REDIS_NAMESPACE=tent-validator " >> .env
```

#### Commandline Runner

```ruby
require 'tent-validator'

# ... code to run your server implementation ...

server_url = "http://127.0.0.1:3000" # change to wherever the server is running

TentValidator.setup!(
  :remote_entity_uri => server_url,
  :remote_server_meta => { # change to suite your server setup
    "entity" => server_url,
    "previous_entities" => [],
    "servers" => [
      {
        "version" => "0.3",
        "urls" => {
          "app_auth_request" => "#{server_url}/oauth/authorize",
          "app_token_request" => "#{server_url}/oauth/token",
          "posts_feed" => "#{server_url}/posts",
          "new_post" => "#{server_url}/posts",
          "post" => "#{server_url}/posts/{entity}/{post}",
          "post_attachment" => "#{server_url}/posts/{entity}/{post}/attachments/{name}?version={version}",
          "batch" => "#{server_url}/batch",
          "server_info" => "#{server_url}/server"
        },
        "preference" => 0
      }
    ]
  },
  :remote_auth_details => {
    # ...
  },
  :tent_database_url => ENV['VALIDATOR_TENTD_DATABASE_URL'] # tent-validator uses tentd
)

TentValidator::Runner::CLI.run
```

#### Browser Runner

You will also need JavaScript runtime (e.g. nodejs).

```bash
echo "VALIDATOR_NOTIFICATION_URL=http://localhost:9292/webhooks 
COOKIE_SECRET=$(openssl rand -hex 16 | tr -d '\r\n') 
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
