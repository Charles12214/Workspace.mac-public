// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Workspace",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Workspace", targets: ["Workspace"])
    ],
    targets: [
        .executableTarget(
            name: "Workspace",
            path: "Sources/Workspace"
        )
    ]
)
