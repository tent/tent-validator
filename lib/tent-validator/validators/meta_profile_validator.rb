require 'faker'

module TentValidator

  class MetaProfileValidator < TentValidator::Spec

    require 'tent-validator/validators/support/post_generators'
    include Support::PostGenerators

    describe "GET post" do
      ##
      # Update meta post to contain a profile
      expect_response(:status => 200, :schema => :data) do
        expect_schema(:post, '/post')
        expect_schema(:post_meta, '/post/content')

        meta_post = TentValidator.remote_server_meta
        data = TentD::Utils::Hash.deep_dup(meta_post)

        data['version'] = {
          'parents' => [
            { 'version' => meta_post['version']['id'], 'post' => meta_post['id'] }
          ]
        }

        data['content']['profile'] = {
          'name' => Faker::Lorem.paragraphs(2).join(' ').slice(0, 256),
          'bio' => Faker::Lorem.paragraphs(2).join(' ').slice(0, 256),
          'website' => "https://#{Faker::Internet.domain_word}.example.com/#{Faker::Internet.domain_word}",
          'location' => Faker::Address.city
        }

        expected_data = TentD::Utils::Hash.deep_dup(data)
        expected_data['version']['parents'][0]['post'] = property_absent
        expected_data['permissions'] = property_absent
        expected_data.delete('published_at')

        avatar_attachment = {
          :content_type => "image/png",
          :category => 'avatar',
          :name => 'fictitious.png',
          :data => "Fake image data"
        }
        attachments = [avatar_attachment]

        expected_data['attachments'] = attachments.map { |a|
          a = a.dup
          a.merge!(:digest => hex_digest(a[:data]), :size => a[:data].size)
          a.delete(:data)
          a
        }

        expect_properties(
          :post => expected_data
        )

        set(:meta_post_data, expected_data)

        res = clients(:app).post.update(meta_post['entity'], meta_post['id'], data, {}, :attachments => attachments)

        if res.status == 200
          TentValidator.remote_server_meta = res.body['post']
        end

        res
      end

      expect_response(:status => 200, :schema => :data) do
        expect_schema(:post, '/post')
        expect_schema(:post_meta, '/post/content')

        expect_properties(:post => get(:meta_post_data))

        TentClient::Discovery.discover(clients(:no_auth), TentValidator.remote_entity_uri, :return_response => true) || Faraday::Response.new({})
      end

      ##
      # Create a post
      expect_response(:status => 200, :schema => :data) do
        expect_schema(:post, '/post')
        expect_schema(:post_status, '/post/content')

        data = generate_status_post

        data[:mentions] = [
          { :entity => TentValidator.remote_entity_uri }
        ]

        expected_data = TentD::Utils::Hash.deep_dup(data)
        expected_data[:permissions] = property_absent
        expected_data[:mentions][0].delete(:entity)

        expect_properties(:post => expected_data)

        res = clients(:app).post.create(data)

        if res.status == 200
          set(:post, res.body['post'])
        else
          set(:post, {})
        end

        res
      end

      ##
      # Expect profile to be returned via profiles=entity
      expect_response(:status => 200, :schema => :data) do
        expect_schema(:post, '/post')
        expect_schema(:post_status, '/post/content')

        post = get(:post)

        meta_profile = get(:meta_post_data)['content']['profile']
        expect_properties(:profiles => {
          post['entity'] => meta_profile
        })

        clients(:app).post.get(post['entity'], post['id'], :profiles => 'entity')
      end

      ##
      # Expect profile to be returned via profiles=mentions
      expect_response(:status => 200, :schema => :data) do
        expect_schema(:post, '/post')
        expect_schema(:post_status, '/post/content')

        post = get(:post)

        meta_profile = get(:meta_post_data)['content']['profile']
        expect_properties(:profiles => {
          post['entity'] => meta_profile
        })

        clients(:app).post.get(post['entity'], post['id'], :profiles => 'mentions')
      end
    end

  end

  TentValidator.validators << MetaProfileValidator
end
