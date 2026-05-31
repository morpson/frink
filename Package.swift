// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "Frink",
    platforms: [.macOS(.v12)],
    dependencies: [
    ],
    targets: [
        .executableTarget(
            name: "Frink",
            dependencies: [
            ],
            resources: [
                .process("Resources")
            ]
        ),
    ]
)
