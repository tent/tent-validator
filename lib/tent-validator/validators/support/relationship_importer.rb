module TentValidator
  module Support
    module RelationshipImporter

      # Imports relationship with fake entity or uses :entity if set
      # Sets
      #   :fake_entity
      #   :remote_entity
      #   :fake_relationship_initial
      #   :fake_credentials
      #   :remote_relationship
      #   :remote_credentials
      #   :fake_relationship
      def include_import_relationship_examples
        # [author:fake] import relationship#initial
        expect_response(:status => 200, :schema => :data) do
          fake_entity = get(:entity) || "http://fictitious-#{TentD::Utils.timestamp}.example.org"
          set(:fake_entity, fake_entity)

          remote_entity = TentValidator.remote_entity_uri
          set(:remote_entity, remote_entity)

          data = {
            :id => TentD::Utils.random_id,
            :published_at => TentD::Utils.timestamp,
            :received_at => TentD::Utils.timestamp,
            :entity => fake_entity,
            :type => "https://tent.io/types/relationship/v0#initial",
            :mentions => [{ :entity => remote_entity }],
            :version => {
              :published_at => TentD::Utils.timestamp,
              :received_at => TentD::Utils.timestamp,
            },
            :permissions => {
              :public => false
            }
          }

          data[:version][:id] = generate_version_signature(data)

          set(:fake_relationship_initial, data)

          expect_properties(:post => data)

          clients(:app_auth).post.update(data[:entity], data[:id], data, {}, :import => true)
        end.after do |response, results, validator|
          if results.any? { |r| !r[:valid] }
            raise SetupFailure.new("Failed to import post", response, results, validator)
          end
        end

        # [author:fake] import credentials (mentions relationship#initial)
        expect_response(:status => 200, :schema => :data) do
          fake_entity = get(:fake_entity)
          fake_relationship_initial = get(:fake_relationship_initial)

          data = {
            :id => TentD::Utils.random_id,
            :published_at => TentD::Utils.timestamp,
            :received_at => TentD::Utils.timestamp,
            :entity => fake_entity,
            :type => "https://tent.io/types/credentials/v0#",
            :mentions => [{
              :entity => fake_entity,
              :post => fake_relationship_initial[:id],
              :type => fake_relationship_initial[:type]
            }],
            :version => {
              :published_at => TentD::Utils.timestamp,
              :received_at => TentD::Utils.timestamp,
            },
            :content => {
              :hawk_key => TentD::Utils.hawk_key,
              :hawk_algorithm => TentD::Utils.hawk_algorithm
            },
            :permissions => {
              :public => false
            }
          }

          data[:version][:id] = generate_version_signature(data)

          set(:fake_credentials, data)

          clients(:app_auth).post.update(data[:entity], data[:id], data, {}, :import => true)
        end.after do |response, results, validator|
          if results.any? { |r| !r[:valid] }
            raise SetupFailure.new("Failed to import post", response, results, validator)
          end
        end

        # [author:remote] import relationship# (mentions relationship#initial)
        expect_response(:status => 200, :schema => :data) do
          fake_entity = get(:fake_entity)
          fake_relationship_initial = get(:fake_relationship_initial)

          remote_entity = get(:remote_entity)

          data = {
            :id => TentD::Utils.random_id,
            :published_at => TentD::Utils.timestamp,
            :received_at => TentD::Utils.timestamp,
            :entity => remote_entity,
            :type => "https://tent.io/types/relationship/v0#",
            :mentions => [{
              :entity => fake_entity,
              :post => fake_relationship_initial[:id],
              :type => fake_relationship_initial[:type]
            }],
            :version => {
              :published_at => TentD::Utils.timestamp,
              :received_at => TentD::Utils.timestamp,
            },
            :permissions => {
              :public => false
            }
          }

          data[:version][:id] = generate_version_signature(data)

          set(:remote_relationship, data)

          clients(:app_auth).post.update(data[:entity], data[:id], data, {}, :import => true)
        end.after do |response, results, validator|
          if results.any? { |r| !r[:valid] }
            raise SetupFailure.new("Failed to import post", response, results, validator)
          end
        end

        # [author:remote] import credentials (mentions relationship#)
        expect_response(:status => 200, :schema => :data) do
          fake_entity = get(:fake_entity)
          fake_relationship_initial = get(:fake_relationship_initial)

          remote_entity = get(:remote_entity)
          remote_relationship = get(:remote_relationship)

          data = {
            :id => TentD::Utils.random_id,
            :published_at => TentD::Utils.timestamp,
            :received_at => TentD::Utils.timestamp,
            :entity => remote_entity,
            :type => "https://tent.io/types/credentials/v0#",
            :mentions => [{
              :entity => remote_entity,
              :post => remote_relationship[:id],
              :type => remote_relationship[:type]
            }],
            :version => {
              :published_at => TentD::Utils.timestamp,
              :received_at => TentD::Utils.timestamp,
            },
            :content => {
              :hawk_key => TentD::Utils.hawk_key,
              :hawk_algorithm => TentD::Utils.hawk_algorithm
            },
            :permissions => {
              :public => false
            }
          }

          data[:version][:id] = generate_version_signature(data)

          set(:remote_credentials, data)

          clients(:app_auth).post.update(data[:entity], data[:id], data, {}, :import => true)
        end.after do |response, results, validator|
          if results.any? { |r| !r[:valid] }
            raise SetupFailure.new("Failed to import post", response, results, validator)
          end
        end

        # [author:fake] import relationship# (mentions [author:remote] relationship#)
        expect_response(:status => 200, :schema => :data) do
          fake_entity = get(:fake_entity)
          fake_relationship_initial = get(:fake_relationship_initial)

          remote_entity = get(:remote_entity)
          remote_relationship = get(:remote_relationship)

          data = {
            :id => fake_relationship_initial[:id],
            :published_at => TentD::Utils.timestamp,
            :received_at => TentD::Utils.timestamp,
            :entity => fake_entity,
            :type => "https://tent.io/types/relationship/v0#",
            :mentions => [{
              :entity => remote_entity,
              :post => remote_relationship[:id],
              :type => remote_relationship[:type]
            }],
            :version => {
              :parents => [{
                :entity => fake_entity,
                :post => fake_relationship_initial[:id],
                :version => fake_relationship_initial[:version][:id]
              }]
            },
            :permissions => {
              :public => false
            }
          }

          data[:version][:id] = generate_version_signature(data)

          set(:fake_relationship, data)

          clients(:app_auth).post.update(data[:entity], data[:id], data, {}, :import => true)
        end.after do |response, results, validator|
          if results.any? { |r| !r[:valid] }
            raise SetupFailure.new("Failed to import post", response, results, validator)
          end
        end
      end

      def include_import_subscription_examples
        expect_response(:status => 200, :schema => :data) do
          data = {
            :id => TentD::Utils.random_id,
            :entity => get(:user).entity,
            :published_at => TentD::Utils.timestamp,
            :received_at => TentD::Utils.timestamp,
            :type => "https://tent.io/types/subscription/v0##{TentClient::TentType.new(get(:type)).to_s(:fragment => false)}",
            :mentions => [{ 'entity' => TentValidator.remote_entity_uri }],
            :content => {
              :type => get(:type)
            },
            :version => {
              :published_at => TentD::Utils.timestamp,
              :received_at => TentD::Utils.timestamp
            },
            :permissions => {
              :public => false,
              :entities => [TentValidator.remote_entity_uri]
            }
          }

          data[:version][:id] = generate_version_signature(data)

          expect_properties(:post => data)

          clients(:app_auth).post.update(data[:entity], data[:id], data, {}, :import => true)
        end.after do |response, results, validator|
          if results.any? { |r| !r[:valid] }
            raise SetupFailure.new("Failed to import subscription post", response, results, validator)
          end
        end
      end

    end
  end
end
