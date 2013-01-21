TentValidator.Routers.results = new class ResultsRouter extends Marbles.Router
  routes: {
    "results" : "results"
  }

  results: (params) =>
    new TentValidator.Views.Results
