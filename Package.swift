// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MuniConvert",
    defaultLocalization: "fr",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MuniConvertCore",
            targets: ["MuniConvertCore"]
        ),
        .library(
            name: "MuniConvertInterop",
            targets: ["MuniConvertInterop"]
        ),
        .executable(
            name: "MuniConvert",
            targets: ["MuniConvert"]
        ),
        .executable(
            name: "municonversion-cli",
            targets: ["municonversion-cli"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", from: "6.0.0"),
        .package(url: "https://github.com/Macthieu/OrchivisteKit.git", branch: "main")
    ],
    targets: [
        .target(
            name: "MuniConvertCore",
            path: "Sources/MuniConvert",
            exclude: [
                "App"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "MuniConvert",
            dependencies: [
                "MuniConvertCore"
            ],
            path: "Sources/MuniConvert/App"
        ),
        .target(
            name: "MuniConvertInterop",
            dependencies: [
                "MuniConvertCore",
                .product(name: "OrchivisteKitContracts", package: "OrchivisteKit")
            ],
            path: "Sources/MuniConvertInterop"
        ),
        .executableTarget(
            name: "municonversion-cli",
            dependencies: [
                "MuniConvertInterop",
                .product(name: "OrchivisteKitContracts", package: "OrchivisteKit"),
                .product(name: "OrchivisteKitInterop", package: "OrchivisteKit")
            ],
            path: "Sources/municonversion-cli"
        ),
        .testTarget(
            name: "MuniConvertTests",
            dependencies: [
                "MuniConvertCore",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests/MuniConvertTests"
        ),
        .testTarget(
            name: "MuniConvertInteropTests",
            dependencies: [
                "MuniConvertInterop",
                .product(name: "OrchivisteKitContracts", package: "OrchivisteKit"),
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests/MuniConvertInteropTests"
        )
    ]
)
