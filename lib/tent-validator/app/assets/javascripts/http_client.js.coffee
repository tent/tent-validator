class TentValidator.HTTPClient extends Marbles.HTTP.Client
  constructor: ->
    super
    @options.middleware ?= [Marbles.HTTP.Client.Middleware.SerializeJSON]
