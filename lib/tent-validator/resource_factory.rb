require 'hashie'

module TentValidator
  class ResourceFactory
    def self.create_resource(example_group, client_options, type, *args)
      factory = new(example_group, client_options, type, *args)
      factory.create_resource
      factory.verify_resource_created
      factory
    end

    attr_reader :schema_name, :type, :example_group, :client_options

    def initialize(example_group, client_options, type, *generator_args)
      @example_group = example_group
      @client_options = client_options
      @type = type
      @generator_args = generator_args
      @schema_name = @client_options.delete(:schema) || @type
      @client_args = @client_options.delete(:client_args) || []
    end

    def create_resource
      example_group.expect_response(:tent, :schema => schema_name, :status => 200, :properties => expected_data) do
        client.create(*(@client_args + [data]))
      end
    end

    def verify_resource_created
      return unless client.respond_to?(:get)
      return unless client.method(:get).arity > 1
      _expected_data = data.slice(:mac_key_id, :mac_key, :mac_algorithm)
      _expected_data[:groups] = data[:groups].map { |g| g.slice('id') } if data[:groups]
      example_group.expect_response(:tent, :schema => schema_name, :status => 200, :properties => _expected_data) do
        client.get(*(@client_args + [data[:id], { :secrets => true }]))
      end
    end

    def data
      @data ||= Hashie::Mash.new(JSONGenerator.generate(type, *@generator_args))
    end

    def expected_data
      @expected_data ||= begin
        _data = Hashie::Mash.new
        blacklist = %w[ mac_key_id mac_key mac_algorithm groups ]
        data.each_pair do |k,v|
          next if blacklist.include?(k.to_s)
          _data[k.to_s] = v
        end
        _data
      end
    end

    def client
      type.to_s.split('_').inject(example_group.clients(:app, client_options)) { |memo, method| memo = memo.send(method) }
    end
  end
end
