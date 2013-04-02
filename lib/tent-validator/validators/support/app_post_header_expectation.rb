TentValidator::ResponseExpectation::HeaderValidator.register(:app_post, {
  'Content-Type' => %r{\Aapplication/vnd\.tent\.post\.v0\+json; rel="https://tent\.io/types/app/v0#\S*"\Z}
})
