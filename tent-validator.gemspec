# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'tent-validator/version'

Gem::Specification.new do |gem|
  gem.name          = "tent-validator"
  gem.version       = TentValidator::VERSION
  gem.authors       = ["Jesse Stuart"]
  gem.email         = ["jesse@jessestuart.ca"]
  gem.description   = %q{Tent protocol validator}
  gem.summary       = %q{Tent protocol validator}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_runtime_dependency 'yajl-ruby'
  gem.add_runtime_dependency 'faraday', '0.8.4'
  gem.add_runtime_dependency 'json-patch'
  gem.add_runtime_dependency 'tent-client'
  gem.add_runtime_dependency 'awesome_print'

  gem.add_development_dependency 'rspec', '~> 2.11'
  gem.add_development_dependency 'mocha', '0.12.6'
  gem.add_development_dependency 'bundler'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'hashie'
end
