// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoiceAgent",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "VoiceAgent",
            targets: ["VoiceAgent"]
        ),
    ],
    dependencies: [
        // Add any external dependencies here if needed
        // For example:
        // .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "VoiceAgent",
            dependencies: [],
            path: "VoiceAgent"
        ),
        .testTarget(
            name: "VoiceAgentTests",
            dependencies: ["VoiceAgent"]
        ),
    ]
)