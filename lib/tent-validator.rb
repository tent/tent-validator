require 'tent-validator/version'
require 'tentd/utils'
require 'api-validator'
require 'faraday'
require 'tent-client'
require 'thread'

module TentValidator

  require 'tent-validator/spec'

  require 'tent-validator/runner'

  require 'tent-validator/faraday/validator_rack_adapter'
  require 'tent-validator/faraday/validator_net_http_adapter'

  class << self
    attr_writer :remote_auth_details
    attr_accessor :remote_server_meta, :remote_entity_uri, :local_database_url, :local_server, :local_server_port, :mutex
  end

  def self.setup!(options = {})
    require 'tentd'
    self.local_database_url = options[:tent_database_url] || ENV['TENT_DATABASE_URL']
    TentD.setup!(:database_url => self.local_database_url)

    require 'tent-validator/tentd/model/user'

    self.local_server = wrap_local_server(TentD::API.new)
    self.mutex = Mutex.new

    [:remote_entity_uri, :remote_auth_details, :remote_server_meta].each do |key|
      if options.has_key?(key)
        self.send("#{key}=", options.delete(key))
      end
    end
  end

  def self.watch_local_requests
    @watch_local_requests ||= Hash.new
  end

  def self.pending_local_requests
    @pending_local_requests ||= []
  end

  def self.wrap_local_server(app)
    lambda do |env|
      match = env['PATH_INFO'] =~ %r{\A(/([^/]+)/tent)(.*)}
      env['PATH_INFO'] = $3.to_s
      env['SCRIPT_NAME'] = $1.to_s

      user_id = $2
      unless env['current_user'] = TentD::Model::User.first(:public_id => user_id)
        return [404, { 'Content-Type' => 'text/plain' }, ['']]
      end

      status, headers, body = app.call(env)

      TentValidator.mutex.synchronize do
        if TentValidator.watch_local_requests[env['current_user'].id]
          env['REQUEST_BODY'] = env['rack.input'].read
          env['rack.input'].rewind
          TentValidator.pending_local_requests << [env, [status, headers, body]]
        end
      end

      [status, headers, body]
    end
  end

  def self.run_local_server!
    return if @local_server_running

    # get random port
    require 'socket'
    tmp_socket = Socket.new(:INET, :STREAM)
    tmp_socket.bind(Addrinfo.tcp("127.0.0.1", 0))
    tentd_host, tentd_port = tmp_socket.local_address.getnameinfo
    tmp_socket.close

    tentd_thread = Thread.new do
      require 'puma/cli'

      puts "Booting Validator Tent server on port #{tentd_port}..."

      STDOUT.reopen '/dev/null'
      STDERR.reopen '/dev/null'

      cli = Puma::CLI.new ['--port', tentd_port.to_s]
      local_server = self.local_server
      cli.instance_eval { @options[:app] = local_server }
      cli.run
    end

    # wait until tentd server boots
    @local_server_running = false
    until @local_server_running
      begin
        Socket.tcp("127.0.0.1", tentd_port) do |connection|
          @local_server_running = true
          connection.close
        end
      rescue Errno::ECONNREFUSED
      end
    end

    TentValidator.local_server_port = tentd_port
  end

  def self.remote_auth_details
    @remote_auth_details || Hash.new
  end

  def self.remote_adapter
    @remote_adapter ||= :validator_net_http
  end

  def self.local_adapter
    @local_adapter ||= [:validator_rack, self.local_server]
  end

  def self.validators
    @validators ||= []
  end

end
