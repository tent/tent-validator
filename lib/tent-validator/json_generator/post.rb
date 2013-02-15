require 'faker'

module TentValidator
  class PostJSONGenerator < JSONGenerator
    register :post

    def base
      {
        :licenses => 3.times.map { Faker::Internet.url },
        :published_at => Time.now.to_i,
        :mentions => [{ :entity => Faker::Internet.url }, { :entity => Faker::Internet.url, :post => 'abc' }]
      }
    end

    def status(options ={})
      base.merge(
        :type => "https://tent.io/types/post/status/v0.1.0",
        :content => {
          :text => Faker::Lorem.paragraph.slice(0, 256),
          :location => {
            :type => 'Point',
            :coordinates => [Faker::Address.longitude.to_f, Faker::Address.latitude.to_f]
          }
        }
      ).merge(options)
    end

    def essay(options = {})
      base.merge(
        :type => "https://tent.io/types/post/essay/v0.1.0",
        :content => {
          :title => Faker::Company.catch_phrase,
          :body => Faker::Lorem.paragraphs(2).join("<br/>"),
          :except => Faker::Lorem.paragraph,
          :tags => Faker::Lorem.words(6)
        }
      ).merge(options)
    end

    def photo(options = {})
      base.merge(
        :type => "https://tent.io/types/post/photo/v0.1.0",
        :content => {
          :caption => Faker::Company.catch_phrase,
          :albums => [],
          :tags => Faker::Lorem.words(4),
          :exif => {}
        }
      ).merge(options)
    end

    def custom(options = {})
      base.merge(
        :type => "https://example.org/types/post/custom/v0.1.0",
        :content => {
          :foos => {
            :bar => [1, 2, 3],
            :baz => ['a', 'b', 'c'],
            :kips => {
              :kit => [5,4,3],
              :klop => [0,1,3]
            }
          },
          :bars => {
            :candy => ['chewy', 'crunchy'],
            :soap => ['hard', 'soft']
          }
        }
      ).merge(options)
    end

    def attachments(n=1)
      n.times.map do |i|
        { :category => 'photos', :filename => "fake_photo#{i}.jpg", :data => "Photo #{1} data would go here", :type => 'image/jpeg' }
      end
    end
  end
end
