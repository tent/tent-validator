#= require lowdash
#= require hogan
#= require marbles
#= require_self
#= require_tree ./models
#= require_tree ./collections
#= require_tree ./templates
#= require_tree ./helpers
#= require_tree ./views
#= require_tree ./routers

window.TentValidator ||= {}
_.extend TentValidator, Marbles.Events, {
  Views: {}
  Models: {}
  Collections: {}
  Routers: {}
  Helpers: {}

  config: {
    BASE_TITLE: document.title
  }

  setPageTitle: (title, options={}) ->
    base_title = @config.BASE_TITLE
    title = title + base_title if title
    title ?= base_title

  run: ->
    return if Marbles.history.started

    @showLoadingIndicator()
    @once 'ready', @hideLoadingIndicator

    @on 'loading:start', @showLoadingIndicator
    @on 'loading:stop',  @hideLoadingIndicator

    Marbles.history.start(@config.history_options)

    Marbles.DOM.on window, 'scroll', (e) => @trigger 'window:scroll', e
    Marbles.DOM.on window, 'resize', (e) => @trigger 'window:resize', e

    @ready = true
    @trigger 'ready'

  showLoadingIndicator: ->
    return console.log('loading:show')
    @_num_running_requests ?= 0
    @_num_running_requests += 1
    @Views.loading_indicator.show() if @_num_running_requests == 1

  hideLoadingIndicator: ->
    return console.log('loading:hide')
    @_num_running_requests ?= 1
    @_num_running_requests -= 1
    @Views.loading_indicator.hide() if @_num_running_requests == 0
}
