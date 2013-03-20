$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'bundler/setup'
require 'mocha_standalone'

require 'tent-validator'

ENV['RACK_ENV'] ||= 'test'

RSpec.configure do |config|
  config.mock_with :mocha
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
