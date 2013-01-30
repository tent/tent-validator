lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'bundler/setup'
require 'tent-validator'
require "tent-validator/tentd/model/user"
require './tent_server'

Sidekiq.configure_client do |config|
  config.redis = { size: 1, url: ENV['REDIS_URL'] }
end

Sequel.single_threaded = true
Sidekiq.configure_server do |config|
  Sequel.single_threaded = false
  config.redis = { url: ENV['REDIS_URL'] }
end
