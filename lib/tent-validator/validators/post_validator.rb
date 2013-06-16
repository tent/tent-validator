require 'tent-validator/validators/support/tent_header_expectation'
require 'tent-validator/validators/support/post_header_expectation'
require 'tent-validator/validators/support/error_header_expectation'

module TentValidator
  class PostValidator < TentValidator::Spec

    require 'tent-validator/validators/new_post_validator'

  end
end
