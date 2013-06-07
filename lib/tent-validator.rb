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

  SetupFailure = Class.new(StandardError)

  class << self
    attr_writer :remote_auth_details
    attr_accessor :remote_server_meta, :remote_entity_uri, :local_database_url, :local_server, :local_server_port, :mutex
  end

  def self.setup!(options = {})
    require 'tentd'
    self.local_database_url = options[:tent_database_url] || ENV['TENT_DATABASE_URL']
    ENV['DB_LOGFILE'] ||= '/dev/null'
    TentD.setup!(:database_url => self.local_database_url)

    require 'tent-validator/tentd/model/user'

    self.local_server = wrap_local_server(TentD::API.new)
    self.mutex = Mutex.new

    [:remote_entity_uri, :remote_auth_details, :remote_server_meta].each do |key|
      if options.has_key?(key)
        self.send("#{key}=", options.delete(key))
      end
    end

    remote_registration
  end

  def self.remote_registration
    client = TentClient.new(remote_entity_uri,
      :faraday_adapter => remote_adapter,
      :server_meta => remote_server_meta
    )

    res = client.post.create(
      :type => "https://tent.io/types/app/v0#",
      :content => {
        :name => "Validator",
        :description => "Tent 0.3 Protocol Validator",
        :url => "http://localhost/validator",
        :redirect_uri => "null://validator/callback",
        :post_types => {
          :read => %w( all ),
          :write => %w( all )
        },
        :scopes => %w( all )
      },
      :permissions => {
        :public => false
      }
    )

    unless res.success?
      raise SetupFailure.new("Failed to register app on remote server! #{res.status}: #{res.body.inspect}")
    end

    app = res.body

    links = TentClient::LinkHeader.parse(res.headers['Link']).links
    credentials_url = links.find { |link| link[:rel] == 'https://tent.io/rels/credentials' }.uri

    unless credentials_url
      raise SetupFailure.new("App credentials not linked! #{res.status}: #{res.headers}")
    end

    res = client.http.get(credentials_url)

    unless res.success?
      raise SetupFailure.new("Failed to fetch app credentials! #{res.status}: #{res.body.inspect}")
    end

    app_credentials = {
      :id => res.body['id'],
      :hawk_key => res.body['content']['hawk_key'],
      :hawk_algorithm => res.body['content']['hawk_algorithm']
    }

    app_client = TentClient.new(remote_entity_uri,
      :faraday_adapter => remote_adapter,
      :server_meta => remote_server_meta,
      :credentials => app_credentials
    )

    oauth_uri = client.oauth_redirect_uri(:client_id => app['id'])

    res = client.http.get(oauth_uri.to_s)
    return (self.remote_auth_details = nil) unless res.status == 302
    oauth_code = Spec.parse_params(URI(res.headers["Location"]).query)['code']

    if res.status == 302
      res = app_client.oauth_token_exchange(:code => oauth_code)
      oauth_credentials = res.body
      self.remote_auth_details = {
        :id => oauth_credentials['access_token'],
        :hawk_key => oauth_credentials['hawk_key'],
        :hawk_algorithm => oauth_credentials['hawk_algorithm']
      }
    else
      self.remote_auth_details = nil
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

      cli = Puma::CLI.new ['--port', tentd_port.to_s]
      local_server = self.local_server
      cli.instance_eval { @options[:app] = local_server; @options[:quiet] = true }
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
    @remote_auth_details
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
