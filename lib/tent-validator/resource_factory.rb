module TentValidator
  class ResourceFactory
    def self.generate_resource_attributes(type, *args)
      JSONGenerator.generate(type, *args)
    end

    def self.create_resource(example_group, client_options, type, *args)
      data = generate_resource_attributes(type, *args)
      expected_data = slice_expected_data(data.dup)
      example_group.expect_response(:tent, :schema => type, :status => 200, :properties => expected_data) do
        example_group.clients(:app, client_options).following.create(data[:entity], data)
      end

      expected_data.inject({}) { |m, (k,v)| m[k.to_s] = v; m }
    end

    def self.slice_expected_data(data)
      %w[ mac_key_id mac_key mac_algorithm groups ].each { |k| data.delete(k) || data.delete(k.to_sym) }
      data
    end
  end
end
