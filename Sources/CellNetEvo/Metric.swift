/// Compute the accuracy of the predictions, assuming that probability is
// evenly distributed for every 1 in the predictions.
public func accuracyScore(predictions: BitmapSequence, targets: BitmapSequence) -> Double {
  var sum = 0.0
  var divisor = 0.0
  for i in 0..<predictions.count {
    divisor += 1.0
    let oneCount = predictions[i].map { $0 ? 1.0 : 0.0 }.reduce(0.0, +)
    if oneCount == 0 {
      // All 0s is treated equivalently to uniform prediction (all 1s)
      sum += 1.0 / Double(predictions.dim)
      continue
    }
    let target = targets[i].firstIndex(of: true)!
    if predictions[i, target] {
      sum += 1 / oneCount
    }
  }
  return sum / divisor
}
