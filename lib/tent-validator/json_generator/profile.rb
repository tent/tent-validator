require 'faker'

module TentValidator
  class ProfileJSONGenerator < JSONGenerator
    register :profile

    def basic
      {
        "name" => Faker::Name.name,
        "avatar_url" => Faker::Internet.url,
        "birthdate" => "",
        "location" => Faker::Address.city,
        "gender" => "",
        "bio" => Faker::Lorem.paragraph,
        "permissions" => {
          "public" => true
        }
      }
    end

    def core
      {
        "entity" => Faker::Internet.url,
        "licenses" => [],
        "servers" => [Faker::Internet.url, Faker::Internet.url],
        "permissions" => {
          "public" => true
        }
      }
    end

    def other
      # public => false in implied
      {
        "bogus field" => Faker::Company.bs
      }
    end

    def bogus
      other
    end

    def example
      # public => false in implied
      {
        "foo bar" => Faker::Lorem.paragraph
      }
    end
  end
end
