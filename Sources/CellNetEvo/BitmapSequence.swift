public struct BitPattern: Sendable {
  private let bitCount: UInt32

  private var shortBits: UInt32 = 0
  private var longBits: [Bool]? = nil

  public var uint32: UInt32? {
    get {
      longBits == nil ? shortBits : nil
    }
    set {
      if let value = newValue {
        assert(longBits == nil)
        shortBits = value
      } else {
        assert(longBits != nil)
      }
    }
  }

  public var count: Int {
    Int(bitCount)
  }

  init(bitCount: Int, shortBits: UInt32 = 0, longBits: [Bool]? = nil) {
    assert(bitCount > 32 || longBits == nil)
    self.bitCount = UInt32(bitCount)
    self.shortBits = shortBits
    self.longBits =
      if bitCount > 32 && longBits == nil {
        [Bool](repeating: false, count: bitCount)
      } else {
        longBits
      }
  }

  public func firstIndex(of: Bool) -> Int? {
    for (i, x) in enumerated() {
      if x == of {
        return i
      }
    }
    return nil
  }

  public func mask(range: Range<Int>) -> BitPattern {
    if let longBits = longBits {
      var newBits = [Bool](repeating: false, count: longBits.count)
      for i in range {
        newBits[i] = longBits[i]
      }
      return BitPattern(bitCount: count, longBits: newBits)
    } else {
      let mask = ((UInt32(1) << range.upperBound) - 1) ^ ((UInt32(1) << range.lowerBound) - 1)
      return BitPattern(bitCount: count, shortBits: shortBits & mask)
    }
  }

  public subscript(_ i: Int) -> Bool {
    get {
      if let b = longBits {
        b[i]
      } else {
        (shortBits & (1 << i)) != 0
      }
    }
    set {
      if longBits != nil {
        longBits![i] = newValue
      } else {
        if newValue {
          shortBits |= (UInt32(1) << i)
        } else {
          shortBits &= ~(UInt32(1) << i)
        }
      }
    }
  }

  public static func & (lhs: BitPattern, rhs: BitPattern) -> BitPattern {
    assert(lhs.bitCount == rhs.bitCount)
    if let lhsBits = lhs.longBits, let rhsBits = rhs.longBits {
      return BitPattern(
        bitCount: lhs.count,
        longBits: zip(lhsBits, rhsBits).map { $0.0 && $0.1 }
      )
    } else {
      return BitPattern(bitCount: lhs.count, shortBits: lhs.shortBits & rhs.shortBits)
    }
  }

  public static func | (lhs: BitPattern, rhs: BitPattern) -> BitPattern {
    assert(lhs.bitCount == rhs.bitCount)
    if let lhsBits = lhs.longBits, let rhsBits = rhs.longBits {
      return BitPattern(
        bitCount: lhs.count,
        longBits: zip(lhsBits, rhsBits).map { $0.0 || $0.1 }
      )
    } else {
      return BitPattern(bitCount: lhs.count, shortBits: lhs.shortBits | rhs.shortBits)
    }
  }

  public static func >> (lhs: BitPattern, rhs: Int) -> BitPattern {
    if let lhsBits = lhs.longBits {
      var newBits = [Bool](repeating: false, count: lhs.count)
      if rhs < lhs.count {
        newBits.replaceSubrange(
          ..<(lhs.count - rhs), with: lhsBits[rhs...])
      }
      return BitPattern(bitCount: lhs.count, longBits: newBits)
    } else {
      return BitPattern(bitCount: lhs.count, shortBits: lhs.shortBits >> rhs)
    }
  }

  public static func << (lhs: BitPattern, rhs: Int) -> BitPattern {
    if let lhsBits = lhs.longBits {
      var newBits = [Bool](repeating: false, count: lhs.count)
      if lhs.count - rhs > 0 {
        newBits.replaceSubrange(
          rhs...,
          with: lhsBits[..<(lhs.count - rhs)]
        )
      }
      return BitPattern(bitCount: lhs.count, longBits: newBits)
    } else {
      let mask = UInt32(0xffff_ffff) >> (32 - lhs.count)
      return BitPattern(bitCount: lhs.count, shortBits: mask & (lhs.shortBits << rhs))
    }
  }
}

extension BitPattern: Sequence {
  public func makeIterator() -> AnyIterator<Bool> {
    var index = 0
    return AnyIterator {
      guard index < self.bitCount else { return nil }
      defer { index += 1 }
      return self[index]
    }
  }
}

public struct BitmapSequence: Sendable {
  public let count: Int
  public let dim: Int
  var values: [BitPattern]

  public init(count: Int, values: [BitPattern], dim: Int? = nil) {
    self.dim = dim ?? values[0].count
    self.count = count
    self.values = values
  }

  public static func zeros(count: Int, dim: Int) -> BitmapSequence {
    return BitmapSequence(
      count: count,
      values: [BitPattern](repeating: BitPattern(bitCount: dim), count: dim * count),
      dim: dim
    )
  }

  mutating public func copy(from: BitmapSequence) {
    values.replaceSubrange(0..<values.count, with: from.values)
  }

  public subscript(_ i: Int) -> BitPattern {
    get {
      values[i]
    }
    set {
      values[i] = newValue
    }
  }

  public subscript(_ i: Int, _ j: Int) -> Bool {
    get {
      return values[i][j]
    }
    set {
      values[i][j] = newValue
    }
  }
}
