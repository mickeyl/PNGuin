// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ScreenGrab",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "ScreenGrabKit", targets: ["ScreenGrabKit"]),
        .executable(name: "iphone-screenshot", targets: ["iphone-screenshot"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .target(name: "ScreenGrabKit"),
        .executableTarget(
            name: "iphone-screenshot",
            dependencies: [
                "ScreenGrabKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(name: "ScreenGrabKitTests", dependencies: ["ScreenGrabKit"]),
    ]
)
