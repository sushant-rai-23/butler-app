// swift-tools-version:5.10
import PackageDescription

// Dependency rule: DoubleApp depends on everything; nothing depends on DoubleApp.
// DoubleCore depends on DoubleProviders and DoubleTools through protocols only.
// DoubleProviders, DoubleTools and DoubleWatch are leaves.
let package = Package(
    name: "Double",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "DoubleApp", targets: ["DoubleApp"]),
        .library(name: "DoubleCore", targets: ["DoubleCore"]),
        .library(name: "DoubleProviders", targets: ["DoubleProviders"]),
        .library(name: "DoubleTools", targets: ["DoubleTools"]),
        .library(name: "DoubleWatch", targets: ["DoubleWatch"]),
    ],
    targets: [
        .executableTarget(
            name: "DoubleApp",
            dependencies: ["DoubleCore", "DoubleProviders", "DoubleTools", "DoubleWatch"]
        ),
        .target(name: "DoubleCore", dependencies: ["DoubleProviders", "DoubleTools"], resources: [.copy("Templates")]),
        .target(name: "DoubleProviders"),
        .target(name: "DoubleTools"),
        .target(name: "DoubleWatch"),

        .testTarget(name: "DoubleAppTests", dependencies: ["DoubleApp", "DoubleCore", "DoubleProviders"]),
        .testTarget(name: "DoubleCoreTests", dependencies: ["DoubleCore", "DoubleProviders", "DoubleTools"]),
        .testTarget(name: "DoubleProvidersTests", dependencies: ["DoubleProviders"]),
        .testTarget(name: "DoubleToolsTests", dependencies: ["DoubleTools"]),
        .testTarget(name: "DoubleWatchTests", dependencies: ["DoubleWatch"]),
    ]
)
