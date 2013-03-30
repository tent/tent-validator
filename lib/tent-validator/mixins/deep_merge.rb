module TentValidator
  module Mixins
    module DeepMerge

      def deep_merge!(hash, *others)
        others.each do |other|
          other.each_pair do |key, val|
            if hash.has_key?(key)
              next if hash[key] == val
              case val
              when Hash
                deep_merge!(hash[key], val)
              when Array
                hash[key].concat(val)
              when FalseClass
                # false always wins
                hash[key] = val
              end
            else
              hash[key] = val
            end
          end
        end
      end

    end
  end
end
