$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'bundler/setup'
require 'webmock/rspec'
require 'mocha_standalone'
require 'tent-validator'

Dir["#{File.dirname(__FILE__)}/support/*.rb"].each { |f| require f }

ENV['RACK_ENV'] ||= 'test'

RSpec.configure do |config|
  config.include WebMock::API
  config.mock_with :mocha
end
