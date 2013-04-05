require 'tent-validator/validators/support/tent_header_expectation'
require 'tent-validator/validators/support/post_header_expectation'
require 'tent-validator/validators/support/error_header_expectation'
require 'tent-validator/validators/support/tent_schemas'

module TentValidator
  class PostValidator < Validator

    require 'tent-validator/validators/new_post_validator'

  end
end