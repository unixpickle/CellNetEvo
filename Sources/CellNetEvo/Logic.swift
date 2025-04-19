// https://github.com/unixpickle/CellNet/blob/5f0e54a682ee8f63a9913d986425189314acc079/Sources/TrainLogic/DataIterator.swift
public struct LogicGateLoader {
  public enum LogicGate {
    case or
    case and
    case xor

    public static func allGates() -> [LogicGate] { [Self.or, Self.and, Self.xor] }
    public static func xorOnly() -> [LogicGate] { [Self.xor] }

    public func apply(_ x: Int, _ y: Int) -> Int {
      switch self {
      case .or: x | y
      case .and: x & y
      case .xor: x ^ y
      }
    }
  }

  public let stepCount: Int
  public let allowedGates: [LogicGate]

  public init(stepCount: Int, allowedGates: [LogicGate] = LogicGate.allGates()) {
    self.stepCount = stepCount
    self.allowedGates = allowedGates
  }

  public func sample() -> (examples: BitmapSequence, targets: BitmapSequence) {
    let gate = allowedGates.randomElement()!

    var examples = BitmapSequence.zeros(count: stepCount, dim: 2)
    var targets = BitmapSequence.zeros(count: stepCount, dim: 1)

    for i in 0..<stepCount {
      let in1 = Int.random(in: 0...1)
      let in2 = Int.random(in: 0...1)
      let out = gate.apply(in1, in2)
      examples[i, 0] = in1 == 0
      examples[i, 1] = in2 == 0
      targets[i, 0] = out == 0
    }
    return (examples: examples, targets: targets)
  }
}
