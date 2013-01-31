require 'sinatra/base'
require 'omniauth-tent'
require "securerandom"
require "tent-validator/sidekiq"

module TentValidator
  class App < Sinatra::Base
    autoload :User, 'tent-validator/app/model/user'
    autoload :SprocketsHelpers, 'tent-validator/app/sprockets/helpers'
    autoload :SprocketsEnvironment, 'tent-validator/app/sprockets/environment'

    def initialize(app=nil, options = {})
      super(app)
      self.class.set :app_name, options[:app_name]
      self.class.set :app_icon, options[:app_icon]
      self.class.set :app_url, options[:app_url]
      self.class.set :app_description, options[:app_description]
      self.class.set :primary_entity, options[:primary_entity]
    end

    configure do
      set :assets, SprocketsEnvironment.assets
      set :cdn_url, false
      set :asset_manifest, false
      set :views, File.expand_path(File.join(File.dirname(__FILE__), 'app', 'views'))
    end

    configure :production do
      set :asset_manifest, Yajl::Parser.parse(File.read(ENV['STATUS_ASSET_MANIFEST'])) if ENV['STATUS_ASSET_MANIFEST']
      if ENV['VALIDATOR_CDN_URL']
        set :cdn_url, ENV['VALIDATOR_CDN_URL']
      end
    end

    helpers do
      def asset_path(path)
        path = asset_manifest_path(path) || [settings.assets.find_asset(path)].compact.map(&:digest_path).first
        if settings.cdn_url?
          "#{settings.cdn_url}/assets/#{path}"
        else
          full_path("/assets/#{path}")
        end
      end

      def asset_manifest_path(asset)
        if settings.asset_manifest?
          settings.asset_manifest['files'].detect { |k,v| v['logical_path'] == asset }[0]
        end
      end

      def path_prefix
        env['SCRIPT_NAME']
      end

      def full_path(path)
        "#{path_prefix}/#{path}".gsub(%r{//}, '/')
      end

      def current_user
        if session['current_user']
          @current_user ||= User.first(:id => session['current_user'].to_i)
        end
      end

      def format_url(url)
        url.to_s.sub(%r{\Ahttps?://}, '')
      end

      def authenticate!
        halt 403 unless current_user
      end

      def json(data)
        [200, { 'Content-Type' => 'application/json' }, [Yajl::Encoder.encode(data)]]
      end

      def run_validations_for(user)
        validation_id = SecureRandom.uuid
        user.update(:validation_id => validation_id)
        ValidationWorker.perform_async(
          :remote_entity => user.entity,
          :remote_server => user.primary_server,
          :remote_auth_details => user.auth_details,
          :validation_id => validation_id
        )
      end
    end

    use OmniAuth::Builder do
      provider :tent,
        :get_app => lambda { |entity| User.get_app_from_entity(entity) },
        :on_app_created => lambda { |app, entity| User.app_created_for_entity(app, entity) },
        :app => {
          :name => TentValidator::App.settings.app_name || '',
          :icon => TentValidator::App.settings.app_icon || '',
          :url =>  TentValidator::App.settings.app_url || 'http://localhost:9292',
          :description => TentValidator::App.settings.app_description || 'Validate Tent server against protocol spec',
          :scopes => {
            "read_posts"        => "Read Posts",
            "write_posts"       => "Write Posts",
            "import_posts"      => "Import Posts",
            "read_profile"      => "Read Profile",
            "write_profile"     => "Write Profile",
            "read_followers"    => "Read Followers",
            "write_followers"   => "Write Followers",
            "read_followings"   => "Read Followings",
            "write_followings"  => "Write Followings",
            "read_groups"       => "Read Groups",
            "write_groups"      => "Write Groups",
            "read_permissions"  => "Read Permissions",
            "write_permissions" => "Write Permissions",
            "read_apps"         => "Read Apps",
            "write_apps"        => "Write Apps",
            "follow_ui"         => "Follow UI",
            "read_secrets"      => "Read Secrets",
            "write_secrets"     => "Write Secrets"
          }
        },
        :post_types => %w( all ),
        :profile_info_types => %w( all )
    end

    if ENV['RACK_ENV'] != 'production' || !ENV['STATUS_CDN_URL']
      get '/assets/*' do
        asset = params[:splat].first
        path = "./public/assets/#{asset}"
        if File.exists?(path)
          content_type = case asset.split('.').last
                         when 'css'
                           'text/css'
                         when 'js'
                           'application/javascript'
                         end
          headers = { 'Content-Type' => content_type } if content_type
          [200, headers, [File.read(path)]]
        else
          new_env = env.clone
          new_env["PATH_INFO"].gsub!("/assets", "")
          settings.assets.call(new_env)
        end
      end
    end

    get '/auth/tent/callback' do
      halt redirect('/') if current_user

      user = User.find_or_create_from_auth_hash(env['omniauth.auth'])
      session['current_user'] = user.id

      unless user.validation_id
        run_validations_for(user)
      end

      redirect '/results'
    end

    get '/auth/failure' do
      redirect '/auth'
    end

    get '/' do
      erb :welcome, :layout => :application
    end

    get '/signout' do
      session.clear
      redirect '/'
    end

    get '/results' do
      authenticate!
      erb :application
    end

    get '/results.json' do
      authenticate!

      results_store = ValidationResultsStore.new(current_user.validation_id)
      json results_store.results
    end

    get '/run' do
      authenticate!
      run_validations_for(current_user)
      redirect '/results'
    end
  end
end
