module TentValidator
  class ResourceFactory
    def self.generate_resource_attributes(type, *args)
      JSONGenerator.generate(type, *args)
    end

    def self.create_resource(example_group, client_options, type, *args)
      data = generate_resource_attributes(type, *args)
      expected_data = slice_expected_data(data.dup)
      schema_name = client_options.delete(:schema) || type
      example_group.expect_response(:tent, :schema => schema_name, :status => 200, :properties => expected_data) do
        example_group.clients(:app, client_options).send(type).create(data)
      end

      example_group.expect_response(:tent, :schema => schema_name, :status => 200, :properties => data.slice(:mac_key_id, :mac_key, :mac_algorithm).merge(:groups => (data[:groups] || []).map { |g| g.slice('id') })) do
        example_group.clients(:app, client_options).send(type).get(data[:id], :secrets => true)
      end

      expected_data.inject({}) { |m, (k,v)| m[k.to_s] = v; m }
    end

    def self.slice_expected_data(data)
      %w[ mac_key_id mac_key mac_algorithm groups ].each { |k| data.delete(k) || data.delete(k.to_sym) }
      data
    end
  end
end
