// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PNGuin",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "PNGuinKit", targets: ["PNGuinKit"]),
        .executable(name: "iphone-screenshot", targets: ["iphone-screenshot"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .target(name: "PNGuinKit"),
        .executableTarget(
            name: "iphone-screenshot",
            dependencies: [
                "PNGuinKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(name: "PNGuinKitTests", dependencies: ["PNGuinKit"]),
    ]
)
