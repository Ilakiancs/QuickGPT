// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuickGPT",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "QuickGPT", targets: ["QuickGPT"])
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "1.16.0"),
        .package(url: "https://github.com/sindresorhus/Defaults", from: "8.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "QuickGPT",
            dependencies: ["KeyboardShortcuts", "Defaults"],
            path: "QuickGPT"
        )
    ]
)
