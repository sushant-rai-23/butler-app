// swift-tools-version:5.10
import PackageDescription

// Dependency rule: ButlerApp depends on everything; nothing depends on ButlerApp.
// ButlerCore depends on ButlerProviders and ButlerTools through protocols only.
// ButlerProviders, ButlerTools and ButlerWatch are leaves.
let package = Package(
    name: "Butler",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ButlerApp", targets: ["ButlerApp"]),
        .library(name: "ButlerCore", targets: ["ButlerCore"]),
        .library(name: "ButlerProviders", targets: ["ButlerProviders"]),
        .library(name: "ButlerTools", targets: ["ButlerTools"]),
        .library(name: "ButlerWatch", targets: ["ButlerWatch"]),
    ],
    targets: [
        .executableTarget(
            name: "ButlerApp",
            dependencies: ["ButlerCore", "ButlerProviders", "ButlerTools", "ButlerWatch"]
        ),
        .target(name: "ButlerCore", dependencies: ["ButlerProviders", "ButlerTools"], resources: [.copy("Templates")]),
        .target(name: "ButlerProviders"),
        .target(name: "ButlerTools"),
        .target(name: "ButlerWatch"),

        .testTarget(name: "ButlerAppTests", dependencies: ["ButlerApp", "ButlerCore", "ButlerProviders"]),
        .testTarget(name: "ButlerCoreTests", dependencies: ["ButlerCore", "ButlerProviders", "ButlerTools"]),
        .testTarget(name: "ButlerProvidersTests", dependencies: ["ButlerProviders"]),
        .testTarget(name: "ButlerToolsTests", dependencies: ["ButlerTools"]),
        .testTarget(name: "ButlerWatchTests", dependencies: ["ButlerWatch"]),
    ]
)
