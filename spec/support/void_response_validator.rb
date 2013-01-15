class VoidResponseValidator < TentValidator::ResponseValidator
  register :void

  def validate(options={})
    super
  end
end
