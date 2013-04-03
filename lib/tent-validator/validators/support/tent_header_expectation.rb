TentValidator::ResponseExpectation::HeaderValidator.register(:tent, {
  'Content-Type' => %r{\Aapplication/vnd\.tent\.post\.v0\+json\b}
})
