// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PlateKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "PlateKit", targets: ["PlateKit"]),
    ],
    targets: [
        .target(name: "PlateKit"),
        .testTarget(name: "PlateKitTests", dependencies: ["PlateKit"]),
    ]
)
