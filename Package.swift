// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OrphanCleaner",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "OrphanCleaner",
            path: "Sources/OrphanCleaner",
            exclude: ["Resources"]
        )
    ]
)
