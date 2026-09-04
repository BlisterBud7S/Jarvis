// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Jarvis",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Jarvis", targets: ["Jarvis"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "Jarvis",
            dependencies: [
                .product(name: "Collections", package: "swift-collections"),
            ],
            path: "Sources"
        ),
    ]
)
