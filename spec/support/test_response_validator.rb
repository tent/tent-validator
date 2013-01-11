class TestValidator < TentValidator::ResponseValidator
  register :test

  def validate(options)
    expect(:body => 'test')
    super
  end
end
