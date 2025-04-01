import Foundation

public struct Model: Sendable {

  public struct Config: Codable, Sendable {
    public let activationCount: Int
    public let stateCount: Int
    public let cellCount: Int

    public var inputStateCount: Int {
      1 << (activationCount + stateCount + 4)
    }

    public var outputStateCount: Int {
      1 << outputStateBits
    }

    public var outputStateBits: Int {
      activationCount + stateCount + 1
    }

    public init(
      activationCount: Int,
      stateCount: Int,
      cellCount: Int
    ) {
      self.activationCount = activationCount
      self.stateCount = stateCount
      self.cellCount = cellCount
    }
  }

  /// A Permutation represents a connection graph between inputs and outputs
  /// for each activation channel.
  public struct Permutation: Sendable {
    public let cellCount: Int
    public let actCount: Int

    /// A [activationCount x cellCount] flattened array of permutations.
    /// Each subrange of cellCount values is a permutation.
    public let mappingsPerAct: [Int]

    public init(cellCount: Int, mappingsPerAct: [Int]) {
      self.cellCount = cellCount
      actCount = (mappingsPerAct.count / cellCount)
      self.mappingsPerAct = mappingsPerAct
      precondition(actCount * self.cellCount == self.mappingsPerAct.count)

      for i in 0..<actCount {
        let subrange = Array(mappingsPerAct[(i * cellCount)..<((i + 1) * cellCount)])
        precondition(subrange.allSatisfy { $0 >= 0 && $0 < cellCount })
        precondition(subrange.count == Set(subrange).count)
      }
    }

    public static func random(cellCount: Int, actCount: Int) -> Permutation {
      var result = [Int]()
      for _ in 0..<actCount {
        result.append(contentsOf: (0..<cellCount).shuffled())
      }
      return Permutation(cellCount: cellCount, mappingsPerAct: result)
    }
  }

  /// A mapping between input state/activations and output state/activations.
  public struct StateMapping: Codable, Equatable, Sendable {
    public let mapping: [Int]
    public let outputStateBits: Int

    public init(mapping: [Int], outputStateBits: Int) {
      self.mapping = mapping
      self.outputStateBits = outputStateBits

      let outCount = 1 << outputStateBits
      precondition(mapping.allSatisfy { $0 < outCount && $0 >= 0 })
    }

    public func callAsFunction(_ x: Int) -> Int {
      assert(x >= 0 && x < mapping.count)
      return mapping[x]
    }

    public static func identity(config: Config) -> StateMapping {
      StateMapping(
        mapping: (0..<config.inputStateCount).map { $0 >> 4 },
        outputStateBits: config.outputStateBits)
    }

    /// Perform random mutations to arrive at a new mapping.
    public func mutate() -> Self {
      let input = mapping
      var result = input

      while result == input {
        // Random swaps
        for _ in 0..<logRandom(count: result.count) {
          let i1 = Int.random(in: 0..<result.count)
          var i2 = Int.random(in: 0..<(result.count - 1))
          if i2 >= i1 {
            i2 += 1
          }
          let x = result[i2]
          result[i2] = result[i1]
          result[i1] = x
        }

        // Random bit flips
        for _ in 0..<logRandom(count: result.count * outputStateBits) {
          let idx = Int.random(in: 0..<result.count)
          let bitIdx = Int.random(in: 0..<outputStateBits)
          result[idx] ^= 1 << bitIdx
        }
      }
      return Self(mapping: result, outputStateBits: outputStateBits)
    }
  }

  public let config: Config
  public let mapping: StateMapping
  public let permutation: Permutation

  public init(config: Config, mapping: StateMapping, permutation: Permutation) {
    precondition(mapping.mapping.count == config.inputStateCount)
    self.config = config
    self.mapping = mapping
    self.permutation = permutation
  }

}

func logRandom(count: Int) -> Int {
  let val = Double.random(in: 0.0..<(log(Double(count))))
  return Int(exp(val))
}
