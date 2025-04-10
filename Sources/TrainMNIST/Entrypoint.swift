import ArgumentParser
import CellNetEvo
import Foundation
import MNIST

@main struct Main: AsyncParsableCommand {
  struct State: Codable {
    let population: Population
    let step: Int
  }

  // Rollout configuration
  @Option(name: .long, help: "Dataset examples per rollout.") var examplesPerRollout: Int = 100
  @Option(name: .long, help: "Number of inference timesteps.") var inferSteps: Int = 5
  @Option(name: .long, help: "Number of update timesteps.") var updateSteps: Int = 5

  // Model configuration
  @Option(name: .long, help: "Number of activations per neuron.") var activationCount: Int = 4
  @Option(name: .long, help: "Number of state bits per neuron.") var stateCount: Int = 4
  @Option(name: .long, help: "Number of cells per network.") var cellCount: Int = 1024

  // Training configuration
  @Option(name: .long, help: "Number of mutated solutions to evaluate per step.")
  var populationCount: Int = 16
  @Option(
    name: .long,
    help: "Number of mutated solutions to keep after each step. Must be less than populationCount.")
  var selectionCount: Int = 4
  @Option(name: .long, help: "Number of rollouts to test per mutation.") var batchSize: Int = 2

  // Saving
  @Option(name: .shortAndLong, help: "Output path.") var outputPath: String = "state.plist"
  @Option(name: .long, help: "Save interval.") var saveInterval: Int = 10

  mutating func run() async {
    print("Command:", CommandLine.arguments.joined(separator: " "))

    do {
      try await train()
    } catch { print("FATAL ERROR: \(error)") }
  }

  mutating func train() async throws {
    let dataset = try await MNISTDataset.download(toDir: "mnist_data")
    let loader = MNISTLoader(images: dataset.train, stepCount: examplesPerRollout)
    let modelConfig = Model.Config(
      activationCount: activationCount,
      stateCount: stateCount,
      cellCount: cellCount
    )
    let rolloutConfig = RolloutConfig(inferSteps: inferSteps, updateSteps: updateSteps)

    var population = Population(
      config: modelConfig,
      solutions: [Model.StateMapping.identity(config: modelConfig)]
    )
    var step = 0

    if FileManager.default.fileExists(atPath: outputPath) {
      print("loading from checkpoint: \(outputPath) ...")
      let data = try Data(contentsOf: URL(fileURLWithPath: outputPath))
      let decoder = PropertyListDecoder()
      let state = try decoder.decode(State.self, from: data)
      population = state.population
      step = state.step
    }

    while true {
      let graphs = (0..<batchSize).map { _ in
        Model.Permutation.random(
          cellCount: modelConfig.cellCount, actCount: modelConfig.activationCount)
      }
      let sequences = (0..<batchSize).map { _ in loader.sample() }
      population = population.mutations(populationCount: populationCount)
      let solutions = population.solutions

      let startTime = DispatchTime.now()
      let fitnesses = SyncObj([Double](repeating: 0.0, count: population.solutions.count))
      DispatchQueue.global(qos: .userInitiated).sync {
        DispatchQueue.concurrentPerform(iterations: solutions.count) { index in
          var solutionFitnesses = [Double]()
          for (graph, (inputs, targets)) in zip(graphs, sequences) {
            let model = Model(
              config: modelConfig,
              mapping: solutions[index],
              permutation: graph
            )
            let preds = rolloutOnCPU(
              rolloutConfig: rolloutConfig, examples: inputs, targets: targets, model: model)
            let score = accuracyScore(predictions: preds, targets: targets)
            solutionFitnesses.append(score)
          }
          let fitness = solutionFitnesses.reduce(0.0, +) / Double(solutionFitnesses.count)
          fitnesses.use { $0[index] = fitness }
        }
      }
      let finalFitnesses = fitnesses.use { $0 }
      population = population.select(
        fitnesses: finalFitnesses,
        selectionCount: selectionCount
      )
      let stopTime = DispatchTime.now()
      let duration = Float(stopTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1e9

      step += 1

      if step % saveInterval == 0 {
        print("saving after \(step) steps...")
        let state = State(
          population: population,
          step: step
        )
        let stateData = try PropertyListEncoder().encode(state)
        try stateData.write(to: URL(filePath: outputPath), options: .atomic)
      }

      print(
        "step \(step): fitness=\(finalFitnesses.reduce(0.0, +) / Double(finalFitnesses.count)) step_time=\(duration)"
      )
    }
  }
}
