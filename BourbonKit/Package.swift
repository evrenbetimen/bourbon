// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BourbonKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BourbonKit", targets: ["BourbonKit"])
    ],
    targets: [
        .target(name: "BourbonKit"),
        .testTarget(name: "BourbonKitTests", dependencies: ["BourbonKit"])
    ]
)
