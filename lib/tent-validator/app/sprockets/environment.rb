require 'logger'
require 'sprockets'
require 'marbles-js'

module TentValidator
  class App
    module SprocketsEnvironment
      def self.assets
        return @assets if defined?(@assets)
        @assets = Sprockets::Environment.new do |env|
          env.logger = Logger.new(STDOUT)
          env.context_class.class_eval do
            include SprocketsHelpers
          end
        end

        %w{ javascripts stylesheets images fonts }.each do |path|
          @assets.append_path(File.expand_path(File.join(File.dirname(__FILE__), '..', "assets", path)))
          @assets.append_path(File.expand_path(File.join(File.dirname(__FILE__), '..', "vendor", "assets", path)))
        end
        MarblesJS.sprockets_setup(@assets)
        @assets
      end
    end
  end
end
