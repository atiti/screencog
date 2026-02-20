// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "screencog",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "screencog", targets: ["screencog"])
    ],
    targets: [
        .executableTarget(
            name: "screencog",
            path: "Sources/screencog"
        ),
        .testTarget(
            name: "screencogTests",
            dependencies: ["screencog"],
            path: "Tests/screencogTests"
        )
    ]
)
