// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FlowRouter",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "FlowRouter", targets: ["FlowRouter"])
    ],
    targets: [
        .executableTarget(
            name: "FlowRouter",
            dependencies: [],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
