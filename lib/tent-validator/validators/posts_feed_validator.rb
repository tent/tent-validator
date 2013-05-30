module TentValidator
  class PostsFeedValidator < TentValidator::Spec

    SetupFailure = Class.new(StandardError)

    require 'tent-validator/validators/support/post_generators'
    include Support::PostGenerators

    def create_post(client, attrs)
      res = client.post.create(attrs)
      raise SetupFailure.new("Failed to create post: #{res.status}\n#{res.body.inspect}") unless res.success?
      res.body
    end

    def create_posts
      client = clients(:app)

      posts = []

      timestamp_offset = 1000
      timestamp = TentD::Utils.timestamp + timestamp_offset
      posts << create_post(client, generate_status_post.merge(:published_at => timestamp, :content => {:text => "first post"}))
      posts << create_post(client, generate_fictitious_post.merge(:published_at => timestamp, :content => {:text => "second post"}))
      posts << create_post(client, generate_status_reply_post.merge(:published_at => TentD::Utils.timestamp + timestamp_offset, :content => {:text => "third post"}))
      posts << create_post(client, generate_status_post.merge(:published_at => TentD::Utils.timestamp + timestamp_offset, :content => {:text => "fourth post"}))
      timestamp = TentD::Utils.timestamp + timestamp_offset
      posts << create_post(client, generate_status_post.merge(:published_at => timestamp, :content => {:text => "fifth post"}))
      posts << create_post(client, generate_fictitious_post.merge(:published_at => timestamp, :content => {:text => "sixth post"}))

      set(:posts, posts)

      post_types = posts.map { |post| post['type'] }.reverse
      set(:post_types, post_types)
    end

    def create_posts_with_mentions
      client = clients(:app)
      posts = []

      _create_post = proc do |post|
        res = client.post.create(post)
        raise SetupFailure.new("Failed to create post: #{res.status}\n#{res.body.inspect}") unless res.success?
        posts << res.body
        res.body
      end

      _ref = _create_post.call(generate_status_post)
      _create_post.call(generate_status_reply_post.merge(:mentions => [{ :entity => _ref['entity'], :post => _ref['id']}]))

      _ref = _create_post.call(generate_status_post)
      _create_post.call(generate_status_reply_post.merge(:mentions => [{ :entity => _ref['entity'], :post => _ref['id']}]))

      set(:mentions_posts, posts)
    end

    describe "GET posts_feed", :before => :create_posts do
      context "without params" do
        expect_response(:status => 200, :schema => :data) do
          expect_properties(:posts => get(:post_types).map { |type| { :type => type } })

          clients(:app).post.list
        end
      end

      context "with type param" do
        expect_response(:status => 200, :schema => :data) do
          types = get(:post_types)
          types = [types.first, types.last]

          expect_properties(:posts => types.map { |type| { :type => type } })

          clients(:app).post.list(:types => types)
        end

        context "when using fragment wildcard" do
          expect_response(:status => 200, :schema => :data) do
            type = TentClient::TentType.new('https://tent.io/types/status/v0')
            expected_types = get(:post_types).select { |t|
              TentClient::TentType.new(t).base == type.base
            }.map { |t| { :type => t } }

            expect_properties(:posts => expected_types)

            clients(:app).post.list(:types => [type.to_s(:fragment => false)])
          end
        end
      end

      context "with entities param" do
        context "when no matching entities" do
          expect_response(:status => 200, :schema => :data) do
            expect_properties(:posts => [])

            clients(:app).post.list(:entities => "https://fictitious.entity.example.org")
          end
        end

        context "when matching entities" do
          expect_response(:status => 200, :schema => :data) do
            entities = get(:posts).map { |p| p['entity'] }
            expect_properties(:posts => entities.map { |e| { :entity => e } })

            clients(:app).post.list(:entities => entities.uniq.join(','))
          end
        end

        # TODO: validate feed with entities param (with proxy)
      end

      context "when using default sort order" do
        expect_response(:status => 200, :schema => :data) do
          posts = get(:posts).sort_by { |post| post['received_at'] * -1 }
          expect_properties(:posts => posts.map { |post| TentD::Utils::Hash.slice(post, 'received_at') })

          clients(:app).post.list(:sort_by => 'received_at')
        end
      end

      context "with sort_by param" do
        context "when received_at" do
          expect_response(:status => 200, :schema => :data) do
            posts = get(:posts).sort_by { |post| post['received_at'] * -1 }
            expect_properties(:posts => posts.map { |post| TentD::Utils::Hash.slice(post, 'received_at') })

            clients(:app).post.list(:sort_by => 'received_at')
          end
        end

        context "when published_at" do
          expect_response(:status => 200, :schema => :data) do
            posts = get(:posts).sort_by { |post| post['published_at'] * -1 }
            expect_properties(:posts => posts.map { |post| TentD::Utils::Hash.slice(post, 'published_at') })

            clients(:app).post.list(:sort_by => 'published_at')
          end
        end

        context "when version.received_at" do
          expect_response(:status => 200, :schema => :data) do
            posts = get(:posts).sort_by { |post| post['version']['received_at'] * -1 }
            expect_properties(:posts => posts.map { |post| { :version => TentD::Utils::Hash.slice(post['version'], 'received_at') } })

            clients(:app).post.list(:sort_by => 'version.received_at')
          end
        end

        context "when version.published_at" do
          expect_response(:status => 200, :schema => :data) do
            posts = get(:posts).sort_by { |post| post['version']['published_at'] * -1 }
            expect_properties(:posts => posts.map { |post| { :version => TentD::Utils::Hash.slice(post['version'], 'published_at') } })

            clients(:app).post.list(:sort_by => 'version.published_at')
          end
        end
      end

      context "pagination" do
        set :sorted_posts do
          get(:posts).sort do |a,b|
            i = a['published_at'] <=> b['published_at']
            i == 0 ? a['version']['id'] <=> b['version']['id'] : i
          end
        end

        context "with since param" do
          context "using timestamp" do
            expect_response(:status => 200, :schema => :data) do
              posts = get(:sorted_posts)

              since_post = posts.shift
              since = since_post['published_at']

              limit = 2
              posts = posts.slice(1, limit).reverse # second post has the same timestamp as the first

              expect_properties(:posts => posts.map { |post| TentD::Utils::Hash.slice(post, 'id', 'published_at') })

              clients(:app).post.list(:since => since, :sort_by => :published_at, :limit => limit)
            end
          end

          context "using timestamp + version" do
            expect_response(:status => 200, :schema => :data) do
              posts = get(:sorted_posts)

              since_post = posts.shift
              since = "#{since_post['published_at']} #{since_post['version']['id']}"

              limit = 2
              posts = posts.slice(0, limit).reverse

              expect_properties(:posts => posts.map { |post| TentD::Utils::Hash.slice(post, 'id', 'published_at') })

              clients(:app).post.list(:since => since, :sort_by => :published_at, :limit => limit)
            end
          end
        end

        context "with until param" do
          context "using timestamp" do
            expect_response(:status => 200, :schema => :data) do
              posts = get(:sorted_posts)

              until_post = posts.shift
              posts.shift # has the same published_at
              until_param = until_post['published_at']

              posts = posts.reverse

              expect_properties(:posts => posts.map { |post| TentD::Utils::Hash.slice(post, 'published_at') })
              expect_property_length('/posts', posts.size)

              clients(:app).post.list(:until => until_param, :sort_by => :published_at)
            end
          end

          context "using timestamp + version" do
            expect_response(:status => 200, :schema => :data) do
              posts = get(:sorted_posts)

              until_post = posts.shift
              until_param = [until_post['published_at'], until_post['version']['id']].join(' ')

              posts = posts.reverse

              expect_properties(:posts => posts.map { |post| TentD::Utils::Hash.slice(post, 'id', 'published_at') })
              expect_property_length('/posts', posts.size)

              clients(:app).post.list(:until => until_param, :sort_by => :published_at)
            end
          end
        end

        context "with before param" do
          context "using timestamp" do
            expect_response(:status => 200, :schema => :data) do
              posts = get(:sorted_posts).reverse

              before_post = posts.shift
              posts.shift # has the same timestamp, don't expect it
              before = before_post['published_at']

              expect_properties(:posts => posts.map { |post| TentD::Utils::Hash.slice(post, 'published_at') })
              expect_property_length('/posts', posts.size)

              clients(:app).post.list(:before => before, :sort_by => :published_at, :limit => posts.size)
            end
          end

          context "using timestamp + version" do
            expect_response(:status => 200, :schema => :data) do
              posts = get(:sorted_posts).reverse

              before_post = posts.shift
              before = [before_post['published_at'], before_post['version']['id']].join(' ')

              expect_properties(:posts => posts.map { |post| TentD::Utils::Hash.slice(post, 'published_at') })
              expect_property_length('/posts', posts.size)

              clients(:app).post.list(:before => before, :sort_by => :published_at, :limit => posts.size)
            end
          end
        end

        context "with before and since params" do
          context "using timestamp" do
            expect_response(:status => 200, :schema => :data) do
              posts = get(:sorted_posts).reverse

              before_post = posts.shift
              posts.shift # same timestamp
              before = before_post['published_at']

              since_post = posts.pop
              posts.pop # same timestamp
              since = since_post['published_at']

              expect_properties(:posts => posts.map { |post| TentD::Utils::Hash.slice(post, 'published_at') })
              expect_property_length('/posts', posts.size)

              clients(:app).post.list(:before => before, :since => since, :sort_by => :published_at)
            end

            expect_response(:status => 200, :schema => :data) do
              posts = get(:sorted_posts)

              before_post = posts.pop
              posts.pop # same timestamp
              before = before_post['published_at']

              since_post = posts.shift
              posts.shift # same timestamp
              since = since_post['published_at']

              limit = 1
              posts = posts.slice(0, limit).reverse # third post

              expect_properties(:posts => posts.map { |post| TentD::Utils::Hash.slice(post, 'published_at') })
              expect_property_length('/posts', posts.size)

              clients(:app).post.list(:before => before, :since => since, :sort_by => :published_at, :limit => limit)
            end
          end

          context "using timestamp + version" do
            expect_response(:status => 200, :schema => :data) do
              posts = get(:sorted_posts).reverse

              before_post = posts.shift
              before = [before_post['published_at'], before_post['version']['id']].join(' ')

              since_post = posts.pop
              since = [since_post['published_at'], since_post['version']['id']].join(' ')

              expect_properties(:posts => posts.map { |post| TentD::Utils::Hash.slice(post, 'published_at') })
              expect_property_length('/posts', posts.size)

              clients(:app).post.list(:before => before, :since => since, :sort_by => :published_at)
            end

            expect_response(:status => 200, :schema => :data) do
              posts = get(:sorted_posts)

              before_post = posts.pop
              before = [before_post['published_at'], before_post['version']['id']].join(' ')

              since_post = posts.shift
              since = [since_post['published_at'], since_post['version']['id']].join(' ')

              limit = 2
              posts = posts.slice(0, limit).reverse # second post, thrid post

              expect_properties(:posts => posts.map { |post| TentD::Utils::Hash.slice(post, 'published_at') })
              expect_property_length('/posts', posts.size)

              clients(:app).post.list(:before => before, :since => since, :sort_by => :published_at, :limit => limit)
            end
          end
        end

        context "with before and until params" do
          context "using timestamp" do
            expect_response(:status => 200, :schema => :data) do
              posts = get(:sorted_posts).reverse

              before_post = posts.shift
              posts.shift # same timestamp
              before = before_post['published_at']

              until_post = posts.pop
              posts.pop # same timestamp
              until_param = until_post['published_at']

              expect_properties(:posts => posts.map { |post| TentD::Utils::Hash.slice(post, 'published_at') })
              expect_property_length('/posts', posts.size)

              clients(:app).post.list(:before => before, :until => until_param, :sort_by => :published_at)
            end

            expect_response(:status => 200, :schema => :data) do
              posts = get(:sorted_posts).reverse

              before_post = posts.shift
              posts.shift # same timestamp
              before = before_post['published_at']

              until_post = posts.pop
              posts.pop # same timestamp
              until_param = until_post['published_at']

              limit = 1
              posts = posts.slice(0, limit)

              expect_properties(:posts => posts.map { |post| TentD::Utils::Hash.slice(post, 'published_at') })
              expect_property_length('/posts', posts.size)

              clients(:app).post.list(:before => before, :until => until_param, :sort_by => :published_at, :limit => limit)
            end
          end

          context "using timestamp + version" do
            expect_response(:status => 200, :schema => :data) do
              posts = get(:sorted_posts).reverse

              before_post = posts.shift
              before = [before_post['published_at'], before_post['version']['id']].join(' ')

              until_post = posts.pop
              until_param = [until_post['published_at'], until_post['version']['id']].join(' ')

              expect_properties(:posts => posts.map { |post| TentD::Utils::Hash.slice(post, 'published_at') })
              expect_property_length('/posts', posts.size)

              clients(:app).post.list(:before => before, :until => until_param, :sort_by => :published_at)
            end

            expect_response(:status => 200, :schema => :data) do
              posts = get(:sorted_posts).reverse

              before_post = posts.shift
              before = [before_post['published_at'], before_post['version']['id']].join(' ')

              until_post = posts.pop
              until_param = [until_post['published_at'], until_post['version']['id']].join(' ')

              limit = 2
              posts = posts.slice(0, limit)

              expect_properties(:posts => posts.map { |post| TentD::Utils::Hash.slice(post, 'published_at') })
              expect_property_length('/posts', posts.size)

              clients(:app).post.list(:before => before, :until => until_param, :sort_by => :published_at, :limit => limit)
            end
          end
        end
      end

      context "with limit param" do
        expect_response(:status => 200, :schema => :data) do
          expect_property_length("/posts", 2)

          clients(:app).post.list(:limit => 2)
        end
      end

      # default limit is 25, make sure there are more than 25 posts (create_posts already called once and it creates 4 posts)
      context "when using default limit", :before => 6.times.map { :create_posts } do
        expect_response(:status => 200, :schema => :data) do
          expect_property_length("/posts", 25)

          clients(:app).post.list
        end
      end

      context "with mentions param", :before => :create_posts_with_mentions do
        context "when single param" do
          context "entity" do
            expect_response(:status => 200, :schema => :data) do
              entity = get(:mentions_posts).first['entity'] # remote entity
              posts = get(:mentions_posts).select { |post|
                post['mentions'] && post['mentions'].any? { |m| m['entity'] == entity }
              }
              expect_properties(:posts => posts.map { |post| { :mentions => post['mentions'].map {|m| {:entity=>m['entity']} } } })

              clients(:app).post.list(:mentions => entity)
            end
          end

          context "entity with post" do
            expect_response(:status => 200, :schema => :data) do
              entity = get(:mentions_posts).first['entity'] # remote entity
              post = get(:mentions_posts).first['id'] # first status post
              posts = [get(:mentions_posts)[1]] # first status post reply
              expect_properties(:posts => posts.map { |post| { :mentions => post['mentions'].map {|m| {:entity=>m['entity'],:post=>m['post']} } } })

              clients(:app).post.list(:mentions => [entity, post].join(' '))
            end
          end

          context "entity OR entity" do
            expect_response(:status => 200, :schema => :data) do
              entity = get(:mentions_posts).first['entity'] # remote entity
              fictitious_entity = "https://fictitious.entity.example.org" # an entity not mentioned by any post on remote server
              posts = get(:mentions_posts).select { |post|
                post['mentions'] && post['mentions'].any? { |m| m['entity'] == entity }
              }
              expect_properties(:posts => posts.map { |post| { :mentions => post['mentions'].map {|m| {:entity=>m['entity']} } } })

              clients(:app).post.list(:mentions => [entity, fictitious_entity].join(','))
            end
          end

          context "entity OR entity with post" do
            expect_response(:status => 200, :schema => :data) do
              entity = get(:mentions_posts).first['entity'] # remote entity
              fictitious_entity = "https://fictitious.entity.example.org" # an entity not mentioned by any post on remote server
              post = get(:mentions_posts).first['id'] # first status post
              posts = [get(:mentions_posts)[1]] # first status post reply
              expect_properties(:posts => posts.map { |post| { :mentions => post['mentions'].map {|m| {:entity=>m['entity'],:post=>m['post']} } } })

              clients(:app).post.list(:mentions => [fictitious_entity, [entity, post].join(' ')].join(','))
            end
          end
        end

        context "when multiple params" do
          context "entity AND entity" do
            expect_response(:status => 200, :schema => :data) do
              entity = get(:mentions_posts).first['entity'] # remote entity
              fictitious_entity = "https://fictitious.entity.example.org" # an entity not mentioned by any post on remote server
              posts = []

              clients(:app).post.list(:mentions => [fictitious_entity, entity])
            end
          end

          context "entity AND entity with post" do
            expect_response(:status => 200, :schema => :data) do
              entity = get(:mentions_posts).first['entity'] # remote entity
              post = get(:mentions_posts).first['id'] # first status post
              posts = [get(:mentions_posts)[1]] # first status post reply

              clients(:app).post.list(:mentions => [entity, [entity, post].join(' ')])
            end

            expect_response(:status => 200, :schema => :data) do
              entity = get(:mentions_posts).first['entity'] # remote entity
              fictitious_entity = "https://fictitious.entity.example.org" # an entity not mentioned by any post on remote server
              post = get(:mentions_posts).first['id'] # first status post
              posts = []

              clients(:app).post.list(:mentions => [fictitious_entity, [entity, post].join(' ')])
            end
          end

          context "(entity OR entity) AND entity" do
            expect_response(:status => 200, :schema => :data) do
              entity = get(:mentions_posts).first['entity'] # remote entity
              fictitious_entity = "https://fictitious.entity.example.org" # an entity not mentioned by any post on remote server
              posts = [get(:mentions_posts)[1]] # first status post reply

              clients(:app).post.list(:mentions => [[fictitious_entity, entity].join(','), entity])
            end

            expect_response(:status => 200, :schema => :data) do
              entity = get(:mentions_posts).first['entity'] # remote entity
              fictitious_entity = "https://fictitious.entity.example.org" # an entity not mentioned by any post on remote server
              other_fictitious_entity = "https://other.fictitious.entity.example.com"
              posts = []

              clients(:app).post.list(:mentions => [[fictitious_entity, other_fictitious_entity].join(','), entity])
            end
          end

          context "(entity OR entity) AND (entity OR entity)" do
            expect_response(:status => 200, :schema => :data) do
              entity = get(:mentions_posts).first['entity'] # remote entity
              fictitious_entity = "https://fictitious.entity.example.org" # an entity not mentioned by any post on remote server
              posts = [get(:mentions_posts)[1]] # first status post reply

              clients(:app).post.list(:mentions => 2.times.map { [fictitious_entity, entity].join(',') })
            end

            expect_response(:status => 200, :schema => :data) do
              entity = get(:mentions_posts).first['entity'] # remote entity
              fictitious_entity = "https://fictitious.entity.example.org" # an entity not mentioned by any post on remote server
              other_fictitious_entity = "https://other.fictitious.entity.example.com"
              posts = []

              clients(:app).post.list(:mentions => [[fictitious_entity, other_fictitious_entity].join(','), [fictitious_entity, entity].join(',')])
            end
          end

          context "(entity OR entity) AND entity with post" do
            expect_response(:status => 200, :schema => :data) do
              entity = get(:mentions_posts).first['entity'] # remote entity
              fictitious_entity = "https://fictitious.entity.example.org" # an entity not mentioned by any post on remote server
              other_fictitious_entity = "https://other.fictitious.entity.example.com"
              post = get(:mentions_posts).first['id'] # first status post
              posts = []

              clients(:app).post.list(:mentions => [[fictitious_entity, other_fictitious_entity].join(','), [entity, post].join(' ')])
            end

            expect_response(:status => 200, :schema => :data) do
              entity = get(:mentions_posts).first['entity'] # remote entity
              fictitious_entity = "https://fictitious.entity.example.org" # an entity not mentioned by any post on remote server
              other_fictitious_entity = "https://other.fictitious.entity.example.com"
              post = get(:mentions_posts).first['id'] # first status post
              posts = [get(:mentions_posts)[1]] # first status post reply

              clients(:app).post.list(:mentions => [[fictitious_entity, entity].join(','), [entity, post].join(' ')])
            end
          end
        end
      end
    end
  end

  TentValidator.validators << PostsFeedValidator
end
