require 'faker'

module TentValidator
  class PostJSONGenerator < JSONGenerator
    register :post

    def status(options ={})
      {
        :type => "https://tent.io/types/post/status/v0.1.0",
        :content => {
          :text => Faker::Lorem.paragraph.slice(0, 256)
        }
      }.merge(options)
    end
  end
end
