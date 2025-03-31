// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "CellNetevo",
  platforms: [.macOS(.v13)],
  products: [
    .library(name: "CellNetEvo", targets: ["CellNetEvo"]),
    .executable(name: "TrainMNIST", targets: ["TrainMNIST"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    .package(url: "https://github.com/unixpickle/honeycrisp-examples.git", from: "0.0.2"),
  ],
  targets: [
    .target(
      name: "CellNetEvo",
      dependencies: [
        .product(name: "MNIST", package: "honeycrisp-examples")
      ]
    ),
    .executableTarget(
      name: "TrainMNIST",
      dependencies: [
        "CellNetEvo",
        .product(name: "MNIST", package: "honeycrisp-examples"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
  ]
)
