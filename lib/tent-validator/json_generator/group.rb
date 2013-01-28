require 'faker'

module TentValidator
  class GroupJSONGenerator < JSONGenerator
    register :group

    def simple(options = {})
      {
        :name => Faker::Name.name
      }.merge(options)
    end
  end
end
