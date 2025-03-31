public struct Population: Codable, Sendable {
  public let config: Model.Config
  public let solutions: [Model.StateMapping]

  public init(config: Model.Config, solutions: [Model.StateMapping]) {
    self.config = config
    self.solutions = solutions
  }

  public func mutations(populationCount: Int) -> Population {
    var newsolutions = self.solutions
    while newsolutions.count < populationCount {
      newsolutions.append(self.solutions.randomElement()!.mutate())
    }
    return Population(config: config, solutions: newsolutions)
  }

  public func select(fitnesses: [Double], selectionCount: Int) -> Population {
    let indices = fitnesses.enumerated().sorted { $0.1 > $1.1 }.prefix(selectionCount).map { $0.0 }
    return Population(config: config, solutions: indices.map { solutions[$0] })
  }
}
