// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "AIStatus",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "AIStatus", targets: ["AIStatus"])
    ],
    targets: [
        .executableTarget(
            name: "AIStatus",
            path: "Sources/AIStatus"
        ),
        .testTarget(
            name: "AIStatusTests",
            dependencies: ["AIStatus"],
            path: "Tests/AIStatusTests"
        )
    ]
)
