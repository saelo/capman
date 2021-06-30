// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "capman",
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.4.0")
    ],
    targets: [
        .target(name: "LibInvesting", dependencies: []),
        .target(name: "capman", dependencies: ["LibInvesting", .product(name: "ArgumentParser", package: "swift-argument-parser")]),

        .testTarget(name: "LibInvestingTests", dependencies: ["LibInvesting"]),
    ]
)
