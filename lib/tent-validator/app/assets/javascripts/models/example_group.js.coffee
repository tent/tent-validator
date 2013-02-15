TentValidator.Models.ExampleGroup = class ExampleGroupModel extends Marbles.Model
  @model_name: 'example_group'

  parseAttributes: (attributes) =>
    name = null
    for k,v of attributes
      name = k
      break
    attributes.name = name
    attributes.results = attributes[name]
    delete attributes[name]

    attributes.passed = true
    for result in attributes.results
      attributes.passed = false unless result.passed

    super(attributes)

  formatHeaders: (headers) =>
    str = ""
    for k, val of headers
      str += "#{k}: #{val}\n"
    str

  sliceSchemaErrors: (schema_keypath, object) =>
    paths = schema_keypath?.split('/')
    return unless paths
    for path in paths
      continue unless object
      object = object[path]
    object

  formatSchemaErrors: (result) =>
    _.map(result.response_schema_errors, (error) =>
      schema_keypath = error.match(/#\/(\S+)/)?[1].replace(/'$/, '')
      "#{error}\n\t#{JSON.stringify(@sliceSchemaErrors(schema_keypath, result.response_body))}"
    ).join("\n\n")

  toJSON: =>
    obj = super
    obj.pending = !@get('results').length
    obj.results = _.map @get('results') || [], (result) =>
      _.extend {}, result, {
        status_passed: !result.failed_status_expectations.length
        headers_passed: !result.failed_headers_expectations.length
        body_passed: !result.failed_body_expectations.length
        schema_passed: !result.response_schema_errors.length
        body_and_schema_passed: !result.failed_body_expectations.length && !result.response_schema_errors.length
        expected_response_body_size_given: result.expected_response_body_size != null
        formatted:
          request:
            headers: "#{result.request_method} #{result.request_url}\n" + @formatHeaders(result.request_headers)
            body: result.request_body
          response:
            status: result.response_status
            headers: @formatHeaders(result.response_headers)
            body: JSON.stringify(result.response_body)
            schema_errors: @formatSchemaErrors(result)
            expected:
              status: result.expected_response_status
              headers: @formatHeaders(result.expected_response_headers)
              body: JSON.stringify(result.expected_response_body)
              body_excludes: result.expected_response_body_excludes
              body_includes: result.expected_response_body_includes
      }
    obj

