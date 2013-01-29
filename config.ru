require './boot'

$stdout.sync = true

use Rack::SslEnforcer, hsts: true if ENV['RACK_ENV'] == 'production'

map '/' do
  use Rack::Session::Cookie,  :key => 'tent-validator.session',
                              :expire_after => 2592000, # 1 month
                              :secret => ENV['COOKIE_SECRET'] || SecureRandom.hex
  use TentValidator::App, app_name: 'Tent Protocol Validator'
  run TentServer.new
end
