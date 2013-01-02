require 'tent-client'

module TentValidator
  class ExampleGroup
    def initialize(description=nil, &block)
      @description = description

      if block
        @block = block
      else
        @pending = true
      end

      @state = {}
    end

    def run
      instance_eval(&@block) if @block
      Results.new(Array(@expectations).map(&:call))
    end

    def pending?
      !!@pending
    end

    def set(key, value)
      @state[key.to_s] = value
    end

    def get(key)
      @state[key.to_s]
    end

    def with_client(type, options, &block)
      client = if options[:server] == :remote
        TentClient.new(TentValidator.remote_server, TentValidator.remote_auth_details)
      else
        TentClient.new("", :faraday_adapter => TentValidator.local_adapter)
      end
      yield(client)
    end

    def expect_response(name, options = {}, &block)
      @expectations ||= []
      @expectations << proc { ResponseValidator.validate(name, options, &block) }
    end
  end
end
