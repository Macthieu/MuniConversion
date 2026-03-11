// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MuniConvert",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "MuniConvert",
            targets: ["MuniConvert"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", from: "6.0.0")
    ],
    targets: [
        .executableTarget(
            name: "MuniConvert",
            path: "Sources/MuniConvert"
        ),
        .testTarget(
            name: "MuniConvertTests",
            dependencies: [
                "MuniConvert",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests/MuniConvertTests"
        )
    ]
)
