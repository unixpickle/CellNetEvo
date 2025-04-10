public struct RolloutConfig: Sendable {
  public let inferSteps: Int
  public let updateSteps: Int

  public init(inferSteps: Int, updateSteps: Int) {
    self.inferSteps = inferSteps
    self.updateSteps = updateSteps
  }
}

public func rolloutOnCPU(
  rolloutConfig: RolloutConfig,
  examples: BitmapSequence,
  targets: BitmapSequence,
  model: Model
) -> BitmapSequence {
  var state = BitmapSequence.zeros(count: model.config.cellCount, dim: model.config.inputStateBits)
  var tmp = BitmapSequence.zeros(count: model.config.cellCount, dim: model.config.inputStateBits)
  var allOutputs = BitmapSequence.zeros(count: targets.count, dim: targets.dim)
  for i in 0..<examples.count {
    injectInputs(&state, inputs: examples[i])
    var outputs: BitmapSequence = BitmapSequence.zeros(count: model.config.cellCount, dim: 1)
    for _ in 0..<rolloutConfig.inferSteps {
      outputs = applyModel(&state, &tmp, model: model)
    }
    for j in 0..<targets.dim {
      allOutputs[i, j] = outputs[j + examples.dim, 0]
    }
    injectTargets(&state, inputCount: examples.dim, targets: targets[i])
    for _ in 0..<rolloutConfig.updateSteps {
      _ = applyModel(&state, &tmp, model: model)
    }
    clearTargets(&state, inputCount: examples.dim, targets: targets[i])
  }
  return allOutputs
}

func injectInputs(_ state: inout BitmapSequence, inputs: BitPattern) {
  for (i, x) in inputs.enumerated() {
    state[i, 2] = true
    state[i, 3] = x
  }
}

func injectTargets(_ state: inout BitmapSequence, inputCount: Int, targets: BitPattern) {
  for (i, x) in targets.enumerated() {
    state[i + inputCount, 0] = true
    state[i + inputCount, 1] = x
  }
}

func clearTargets(_ state: inout BitmapSequence, inputCount: Int, targets: BitPattern) {
  for i in 0..<targets.count {
    state[i + inputCount, 0] = false
    state[i + inputCount, 1] = false
  }
}

func applyModel(_ state: inout BitmapSequence, _ tmp: inout BitmapSequence, model: Model)
  -> BitmapSequence
{
  precondition(state.dim <= 32, "cannot use fast bitwise arithmetic for large states")

  var outputs = BitmapSequence.zeros(count: model.config.cellCount, dim: 1)
  for i in 0..<model.config.cellCount {
    let bits = state[i]
    let stateAndActCount = model.config.activationCount + model.config.stateCount
    let bitValue = bits.mask(range: 0..<stateAndActCount)
    let newBitValue = UInt32(model.mapping(Int(bitValue.uint32!)))
    tmp[i] =
      state[i].mask(range: 0..<4)
      | (BitPattern(bitCount: bits.count, shortBits: newBitValue).mask(range: 0..<stateAndActCount)
        << 4)
    outputs[i, 0] = newBitValue & (1 << stateAndActCount) != 0
  }
  permuteActivations(input: tmp, output: &state, model: model)
  return outputs
}

func permuteActivations(input: BitmapSequence, output: inout BitmapSequence, model: Model) {
  // NOTE: input and output should already have the same input/target fields
  for i in 0..<model.config.activationCount {
    for (dst, src) in model.permutation.mappingsPerAct[
      (i * model.config.cellCount)..<((i + 1) * model.config.cellCount)
    ].enumerated() {
      output[dst, i + 4] = input[src, i + 4]
    }
  }
}
