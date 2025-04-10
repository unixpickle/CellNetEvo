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
  }
  return allOutputs
}

func injectInputs(_ state: inout BitmapSequence, inputs: BitPattern) {
  for (i, x) in inputs.enumerated() {
    state[i, 2] = true
    state[i, 3] = x
  }
  for i in inputs.count..<state.count {
    state[i, 2] = false
    state[i, 3] = false
  }
}

func injectTargets(_ state: inout BitmapSequence, inputCount: Int, targets: BitPattern) {
  for (i, x) in targets.enumerated() {
    state[i + inputCount, 0] = true
    state[i + inputCount, 1] = x
  }
  for i in (inputCount + targets.count)..<state.count {
    state[i, 0] = false
    state[i, 1] = false
  }
}

func applyModel(_ state: inout BitmapSequence, _ tmp: inout BitmapSequence, model: Model)
  -> BitmapSequence
{
  tmp.copy(from: state)
  var outputs = BitmapSequence.zeros(count: model.config.cellCount, dim: 1)
  for i in 0..<model.config.cellCount {
    let bits = state[i]
    var bitValue: Int = 0
    for (j, b) in bits.enumerated() {
      if b {
        bitValue |= 1 << j
      }
    }
    let newBitValue = model.mapping(bitValue)
    for j in 0..<(model.config.activationCount + model.config.stateCount) {
      tmp[i, 4 + j] = (newBitValue & (1 << j)) != 0
    }
    outputs[i, 0] =
      newBitValue & (1 << (model.config.activationCount + model.config.stateCount)) != 0
  }
  permuteActivations(input: tmp, output: &state, model: model)
  return outputs
}

func permuteActivations(input: BitmapSequence, output: inout BitmapSequence, model: Model) {
  output.copy(from: input)
  for i in 0..<model.config.activationCount {
    for (dst, src) in model.permutation.mappingsPerAct[
      (i * model.config.cellCount)..<((i + 1) * model.config.cellCount)
    ].enumerated() {
      output[dst, i + 4] = input[src, i + 4]
    }
  }
}
