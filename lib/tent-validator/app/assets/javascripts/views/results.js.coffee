TentValidator.Views.Results = class ResultsView extends Marbles.View
  @view_name: 'results'
  @template_name: 'results'
  @partial_names: ['_example_group', '_result']

  initialize: =>
    @set('container', TentValidator.Views.container)
    client = new TentValidator.HTTPClient
    client.get '/results.json', {},
      success: (res, xhr) =>
        @render(@context(new TentValidator.Collections.ExampleGroups(raw: res)))

  context: (example_groups) =>
    example_groups: _.map( example_groups.models(), (example_group) => example_group.toJSON() )

