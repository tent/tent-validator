# TentValidator::Validation

## Usage

```ruby
class SomeValidator < TentValidator::Validator

  def create_resource
    # ...
    set(:resource, data)
  end

  def fudge_resource
    # ...
    set(:resource, fudged_data)
  end

  describe "GET /posts/{entity}/{id}", :api_doc => :get_resource do
    shared_example :not_found do
      expect_response(:schema => :error, :status => 404) do
        client = authorized_client || clients(:no_auth, :server => :remote)
        client.post.get( get(:resource, :entity), get(:resource, :id) )
      end
    end

    context "when resource exists", :before => :create_resource do
      context "when authorized to read all posts" do
        authorize!(:server => :remote, :scopes => %w[ read_posts ], :read_types => %w[ all ])

        expect_response(:headers => :tent, :schema => :post_status, :status => 200) do
          expect_properties(:entity => get(:resource, :entity), :id => get(:resource, :id))

          expect_property_absent('content.foobar')
          expect_property_present('content.text')

          authorized_client.post.get( get(:resource, :entity), get(:resource, :id) )
        end
      end

      context "when authorize to write resource but not read" do
        authorize!(:server => :remote, :scopes => %w[ write_posts ], :write_types => %w[ all ])
        behaves_as :not_found
      end

      context "when not authorized" do
        behaves_as :not_found
      end
    end

    context "when resource does not exist", :before => :fudge_resource do
      behaves_as :not_found
    end
  end

end
```

### `#describe` and `#context`

`#describe(message, options = {}, &block)` and `#context(message, options = {}, &block)` methods are both the same method and can be arbritrailty nested.

**Options**

name      | type   | description
----      | ----   | -----------
`before`  | symbol | method name to be called for setup required by block (e.g. setup auth)
`api_doc` | symbol | documentation identifier, used when generating API docs

### `#shared_example`

`#shared_example(name, &block)`

Block has access to the same scope as the block it's included into via `#behaves_as`.

### `#behaves_as`

`#behaves_as(name)`

Includes a shared example into current scope.

### `#expect_response`

`#expect_response(options = {}, &block)`

Must be nested under `#describe`, `#context`, or `#shared_example`.

**Options**

name | type | description
---- | ---- | -----------
`headers` | symbol | name of registered header validation
`status` | integer | expected status code
`schema` | symbol | JSON schema to validate response body against
`list` | boolean | set to `true` if response is a list

### `#expect_properties`

`#expect_properties(properties)`

Must be nested under `#expect_response`.

Sets expectation for given key/value pairs to be present in response body JSON. If `list` is set to true in parent `#expect_response` options, the expectation is set for all members of the list.

Setting the value of a key to a hash performs a least common match (e.g. `{ :foo => { :bar => 321 } }` will match `{ :foo => { :bar => 321, :baz => 'BIZ' }, :biz => 'BAZ' }`).

### `#expect_property_absent`

`#expect_property_absent(json_pointer)`

Must be nested under `#expect_response`.

Sets expectation for given [json pointer](http://tools.ietf.org/html/draft-ietf-appsawg-json-pointer-07) to not exist.

### `#expect_property_present`

`#expect_property_present(json_pointer)`

Must be nested under `#expect_response`.

Sets expectation for given [json pointer](http://tools.ietf.org/html/draft-ietf-appsawg-json-pointer-07) to exist.

### `#expect_list_excludes`

`#expect_list_excludes(properties, [properties, ...])`

Must be nested under `#expect_response`.

Only valid for list responses.

Sets expectation for given set(s) of properties to not be present in response list.

### `#expect_list_includes`

`#expect_list_includes(properties, [properties, ...], position)`

Must be nested under `#expect_response`.

Only valid for list responses.

Sets expectation for given set(s) of properties to be present in response list.

`position` argument can be used to specify where given set(s) of properties should be matched. `:start` sets expectation that properties appear in order from the beginning of the list. `:end` sets expectation that properties appear in order at the end of list. `:anywhere` sets expectation that properties are included in list (in any order and not necessarily together). Set `position` to a hash to specify specify a specific start or end index (`:start => 3` or `:end => 5`).

### `#authorized_client`

Must be nested under `#expect_response`.

Returns a client instance authorized with permissions specified in the closest call to `#authorize!`. Returns `nil` if `#authorize!` not called.

