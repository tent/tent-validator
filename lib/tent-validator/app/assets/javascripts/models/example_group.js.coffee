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

  toJSON: =>
    obj = super
    obj.results = _.map @get('results') || [], (result) =>
      _.extend {}, result, {
        status_passed: !result.failed_status_expectations.length
        headers_passed: !result.failed_headers_expectations.length
        body_passed: !result.failed_body_expectations.length
        schema_passed: !result.response_schema_errors.length
        formatted:
          request:
            headers: "#{result.request_method} #{result.request_url}\n" + @formatHeaders(result.request_headers)
            body: result.request_body
          response:
            status: result.response_status
            headers: @formatHeaders(result.response_headers)
            body: result.response_body
            schema_errors: result.response_schema_errors.join("\n")
            expected:
              status: result.expected_response_status
              headers: @formatHeaders(result.expected_response_headers)
              body: result.expected_response_body
      }
    obj

