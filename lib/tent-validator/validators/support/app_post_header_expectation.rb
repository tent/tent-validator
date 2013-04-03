TentValidator::ResponseExpectation::HeaderValidator.register(:app_post, {
  'Content-Type' => %r{\btype=['"]https://tent\.io/types/app/v0#\S*['"]}
})
