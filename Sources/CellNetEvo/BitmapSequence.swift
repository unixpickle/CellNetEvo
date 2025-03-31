public struct BitmapSequence: Sendable {
  public let count: Int
  public let dim: Int
  var values: [Bool]

  public init(count: Int, values: [Bool]) {
    dim = values.count / count
    self.count = count
    self.values = values
    precondition(dim * count == values.count)
  }

  public static func zeros(count: Int, dim: Int) -> BitmapSequence {
    return BitmapSequence(count: count, values: [Bool](repeating: false, count: dim * count))
  }

  public subscript(_ i: Int) -> [Bool] {
    return Array(values[i * dim..<((i + 1) * dim)])
  }

  public subscript(_ i: Int, _ j: Int) -> Bool {
    get {
      return values[i * dim + j]
    }
    set {
      values[i * dim + j] = newValue
    }
  }
}
