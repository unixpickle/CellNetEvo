import MNIST

public struct MNISTLoader {
  let images: [MNISTDataset.Image]
  let stepCount: Int

  public init(images: [MNISTDataset.Image], stepCount: Int) {
    self.images = images
    self.stepCount = stepCount
  }

  public func sample() -> (pixels: BitmapSequence, labels: BitmapSequence) {
    var examples = BitmapSequence.zeros(count: stepCount, dim: 28 * 28)
    var targets = BitmapSequence.zeros(count: stepCount, dim: 10)
    for (i, img) in images.shuffled()[0..<stepCount].enumerated() {
      for (j, pixel) in img.pixels.enumerated() {
        examples[i, j] = UInt8.random(in: 0...255) <= pixel
      }
      targets[i, img.label] = true
    }
    return (pixels: examples, labels: targets)
  }
}
