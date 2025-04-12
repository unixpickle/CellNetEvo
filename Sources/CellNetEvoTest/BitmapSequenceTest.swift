import Testing

@testable import CellNetEvo

@Test func bitmapOperations() async throws {
  for _ in 0..<1000 {
    let bitCount = Int.random(in: 0...64)
    var actual1 = BitPattern(bitCount: bitCount)
    var actual2 = BitPattern(bitCount: bitCount)
    var expected1 = UInt64(0)
    var expected2 = UInt64(0)
    for i in 0..<bitCount {
      if Bool.random() {
        actual1[i] = true
        expected1 |= 1 << i
      }
      if Bool.random() {
        actual2[i] = true
        expected2 |= 1 << i
      }
    }
    #expect(bitsAreEqual(actual1, expected1))
    #expect(bitsAreEqual(actual2, expected2))
    #expect(bitsAreEqual(actual1 | actual2, expected1 | expected2))
    #expect(bitsAreEqual(actual1 & actual2, expected1 & expected2))
    #expect(bitsAreEqual(actual1 << 1, expected1 << 1))
    #expect(bitsAreEqual(actual1 << 10, expected1 << 10))
    #expect(bitsAreEqual(actual1 >> 1, expected1 >> 1))
    #expect(bitsAreEqual(actual1 >> 10, expected1 >> 10))
    if bitCount > 5 {
      #expect(bitsAreEqual(actual1.mask(range: 1..<3), expected1 & 6))
    }
  }
}

func bitsAreEqual(_ seq: BitPattern, _ val: UInt64) -> Bool {
  for i in 0..<seq.count {
    let valAtI: Bool = seq[i]
    if valAtI != ((val & (1 << i)) != 0) {
      return false
    }
  }
  return true
}
