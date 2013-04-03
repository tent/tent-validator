TentValidator::ResponseExpectation::HeaderValidator.register(:post, {
  'Content-Type' => lambda { |response|
    post_type = response.env['expected_post_type'] ? response.env['expected_post_type'] : nil
    post_type ||= (Hash === response.body && response.body['type']) ? response.body['type'] : nil
    if post_type
      %r{\btype=['"]#{ Regexp.escape(post_type) }['"]}
    else
      %r{\btype=['"][^'"]+['"]}
    end
  }
})
