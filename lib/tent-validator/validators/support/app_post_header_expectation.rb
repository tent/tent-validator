TentValidator::ResponseExpectation::HeaderValidator.register(:app_post, {
  'Content-Type' => %r{\Aapplication/vnd\.tent\.post\.v0\+json; type=['"]https://tent\.io/types/app/v0#\S*['"]\Z}
})
